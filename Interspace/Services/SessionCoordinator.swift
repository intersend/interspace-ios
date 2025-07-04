import Foundation
import Combine
import SwiftUI

// MARK: - Session Coordinator

@MainActor
final class SessionCoordinator: ObservableObject {
    static let shared = SessionCoordinator()
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated = false
    @Published var currentUser: UserV2?
    @Published var activeProfile: SmartProfile?
    @Published var sessionState: SessionState = .loading
    @Published var error: SessionError?
    @Published var showError = false
    @Published var profileSwitchProgress: Double = 0.0
    @Published var isSwitchingProfile = false
    
    // MARK: - Private Properties
    
    private let authManager = AuthenticationManagerV2.shared
    private let profileAPI = ProfileAPI.shared
    private let userAPI = UserAPI.shared
    private let cacheManager = UserCacheManager.shared
    private let dataSyncManager = DataSyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Profile cache for performance
    private var profileCache: [String: ProfileCacheEntry] = [:]
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    // Concurrent switch prevention
    private var currentSwitchTask: Task<Void, Error>?
    
    // Session security
    private var sessionSecurityTimer: Timer?
    private let sessionTimeout: TimeInterval = 1800 // 30 minutes
    
    // Background refresh management
    private var isRefreshingInBackground = false
    private var lastRefreshTime: Date?
    private let minimumRefreshInterval: TimeInterval = 60 // 1 minute minimum between refreshes
    
    // MARK: - Initialization
    
    private init() {
        // Clear any error state from previous sessions
        error = nil
        showError = false
        
        setupBindings()
        setupSessionSecurity()
        
        // Delay session initialization to ensure app is ready
        Task {
            // Small delay to ensure app state is ready
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await MainActor.run {
                initializeSession()
            }
        }
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind authentication state
        authManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
                if isAuthenticated {
                    Task {
                        await self?.loadUserSession()
                    }
                } else {
                    self?.clearSession()
                }
            }
            .store(in: &cancellables)
        
        // Bind current user
        authManager.$currentUser
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentUser, on: self)
            .store(in: &cancellables)
        
        // Bind authentication errors
        authManager.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authError in
                if let authError = authError {
                    self?.error = .authenticationError(authError)
                    self?.showError = true
                }
            }
            .store(in: &cancellables)
        
        // Monitor app lifecycle for session security
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppForeground()
            }
            .store(in: &cancellables)
        
        // Listen for authentication expiry notifications
        NotificationCenter.default.publisher(for: .authenticationExpired)
            .sink { [weak self] _ in
                Task { @MainActor in
                    print("🔐 SessionCoordinator: Received authentication expired notification")
                    await self?.handleAuthExpiry()
                }
            }
            .store(in: &cancellables)
        
        // Listen for profile deletion notifications
        NotificationCenter.default.publisher(for: .profileDidDelete)
            .sink { [weak self] notification in
                if let profileId = notification.userInfo?["profileId"] as? String {
                    Task { @MainActor in
                        print("🔐 SessionCoordinator: Received profile deletion notification for \(profileId)")
                        await self?.clearProfileFromCache(profileId: profileId)
                        
                        // If we have remaining profiles, update the UserDefaults cache
                        if let remainingProfiles = notification.userInfo?["remainingProfiles"] as? [SmartProfile] {
                            // Update persistent cache with remaining profiles
                            await self?.cacheManager.cacheProfiles(remainingProfiles)
                            
                            // If the deleted profile was active, only update if there's a new active profile
                            if self?.activeProfile?.id == profileId {
                                // Find the new active profile from remaining profiles
                                if let newActive = remainingProfiles.first(where: { $0.isActive }) {
                                    // Directly update to new active profile without clearing first
                                    self?.activeProfile = newActive
                                    self?.cacheProfile(newActive)
                                    await self?.cacheManager.cacheActiveProfile(newActive)
                                } else if remainingProfiles.isEmpty {
                                    // Only clear if no profiles remain
                                    self?.activeProfile = nil
                                    await self?.cacheManager.cacheActiveProfile(nil)
                                }
                                // If there are remaining profiles but none active, keep current until switchProfile is called
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSessionSecurity() {
        resetSessionTimer()
    }
    
    private func resetSessionTimer() {
        sessionSecurityTimer?.invalidate()
        sessionSecurityTimer = Timer.scheduledTimer(withTimeInterval: sessionTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.handleSessionTimeout()
            }
        }
    }
    
    private func initializeSession() {
        sessionState = .loading
        
        // Try to load from cache first for instant UI
        Task {
            await loadCachedSession()
        }
        
        // Check if user is already authenticated (stored tokens)
        // This synchronously sets the token in APIService if found
        authManager.checkAuthenticationStatus()
        
        // If authenticated after token check, ensure token is set before any API calls
        if authManager.isAuthenticated {
            print("🔐 SessionCoordinator: User authenticated from stored tokens")
            // Token should already be set in APIService by checkAuthenticationStatus
            // The auth state change will trigger loadUserSession via the binding
        }
    }
    
    private func loadCachedSession() async {
        // Don't try to load cached session if we're already unauthenticated
        if sessionState == .unauthenticated {
            print("🔐 SessionCoordinator: Already in unauthenticated state, skipping cache check")
            return
        }
        
        let cachedData = await cacheManager.preloadCache()
        
        if cachedData.isAuthenticated,
           let user = cachedData.user,
           let profiles = cachedData.profiles {
            
            // IMPORTANT: Validate token before showing cached UI
            print("🔐 SessionCoordinator: Validating cached session token...")
            let isTokenValid = await authManager.validateAuthToken()
            
            if !isTokenValid {
                print("🔐 SessionCoordinator: Cached session has invalid token, clearing session")
                sessionState = .unauthenticated
                await cacheManager.clearAllCacheAsync()
                return
            }
            
            // Token is valid, update UI with cached data
            await MainActor.run {
                // Convert cached User to UserV2
                self.currentUser = UserV2(
                    id: user.id,
                    email: user.email,
                    isGuest: user.isGuest
                )
                self.isAuthenticated = true
                
                // Profiles are already SmartProfiles from cache
                let smartProfiles = profiles
                
                // Set active profile
                if let activeProfile = smartProfiles.first(where: { $0.isActive }) {
                    self.activeProfile = activeProfile
                    self.sessionState = .authenticated
                    self.cacheProfile(activeProfile)
                } else if let firstProfile = smartProfiles.first {
                    self.activeProfile = firstProfile
                    self.sessionState = .authenticated
                    self.cacheProfile(firstProfile)
                } else if profiles.isEmpty {
                    self.sessionState = .needsProfile
                }
            }
            
            print("🔐 SessionCoordinator: Loaded cached session data with valid token")
        }
    }
    
    // MARK: - Session Management
    
    func loadUserSession() async {
        do {
            sessionState = .loading
            
            // Ensure we have a valid token before proceeding
            guard APIService.shared.getAccessToken() != nil else {
                print("🔴 SessionCoordinator: No access token available, cannot load user session")
                sessionState = .unauthenticated
                return
            }
            
            // Check if current user is a guest
            if let currentUser = authManager.currentUser, currentUser.isGuest {
                print("🔐 SessionCoordinator: Guest user detected, skipping API calls")
                self.currentUser = currentUser
                self.activeProfile = nil
                sessionState = .authenticated
                return
            }
            
            // Try to load from cache first for faster launch
            if let cachedUser = cacheManager.getCachedUser(),
               let cachedProfiles = cacheManager.getCachedProfiles(),
               cachedUser.id == currentUser?.id {
                print("🔐 SessionCoordinator: Using cached data for quick launch")
                
                // Apply cached data immediately
                // Convert cached User to UserV2
                currentUser = UserV2(
                    id: cachedUser.id,
                    email: cachedUser.email,
                    isGuest: cachedUser.isGuest
                )
                
                if let activeProfile = cacheManager.getCachedActiveProfile() {
                    self.activeProfile = activeProfile
                    cacheProfile(activeProfile)
                }
                
                // Update session state based on cached data
                if !cachedProfiles.isEmpty && activeProfile != nil {
                    sessionState = .authenticated
                } else if cachedProfiles.isEmpty {
                    sessionState = .needsProfile
                }
                
                // Refresh data in background (without causing infinite loop)
                Task.detached(priority: .background) { [weak self] in
                    await self?.refreshUserDataInBackground()
                }
                
                return
            }
            
            // No cache available, load from API
            print("🔐 SessionCoordinator: No cache available, loading from API")
            
            // Load user data and profiles concurrently for non-guest users
            async let userTask = userAPI.getCurrentUser()
            async let profilesTask = profileAPI.getProfiles()
            
            let (user, profiles): (User, [SmartProfile])
            do {
                (user, profiles) = try await (userTask, profilesTask)
                print("🔐 SessionCoordinator: Successfully loaded user and \(profiles.count) profiles")
            } catch let userError as APIError {
                print("🔐 SessionCoordinator: Failed to load user data: \(userError)")
                throw SessionError.sessionLoadFailed("Failed to load user data: \(userError.localizedDescription)")
            } catch {
                print("🔐 SessionCoordinator: Unexpected error loading session: \(error)")
                throw SessionError.sessionLoadFailed("Unexpected error: \(error.localizedDescription)")
            }
            
            // Update UI on main thread
            await MainActor.run {
                // Convert User to UserV2
                self.currentUser = UserV2(
                    id: user.id,
                    email: user.email,
                    isGuest: user.isGuest
                )
            }
            
            // Cache all the data in background
            Task.detached(priority: .background) {
                await self.cacheManager.cacheUser(user)
                await self.cacheManager.cacheProfiles(profiles)
            }
            
            // Check if this is an orphan account (first time sign-in with no profiles)
            if profiles.isEmpty {
                print("🔐 SessionCoordinator: New user detected - no profiles exist")
                
                // In V2, profiles are created automatically during authentication
                print("🔐 SessionCoordinator: User email: \(user.email ?? "none")")
                
                // For all new users, we need them to create their first profile
                sessionState = .needsProfile
                return
            }
            
            // Find and cache active profile
            if let active = profiles.first(where: { $0.isActive }) {
                activeProfile = active
                cacheProfile(active)
                // Cache the active profile as SmartProfile
                await cacheManager.cacheActiveProfile(active)
                
                // Cache auth state with token
                if let token = KeychainManager.shared.getAccessToken() {
                    cacheManager.cacheAuthState(isAuthenticated: true, token: token)
                }
                
                // Preload adjacent profiles for faster switching
                await preloadAdjacentProfiles(current: active, all: profiles)
                sessionState = .authenticated
            } else {
                // User has profiles but none are active - activate the first one
                print("⚠️ SessionCoordinator: No active profile found, activating first profile")
                if let firstProfile = profiles.first {
                    do {
                        try await switchProfile(firstProfile)
                    } catch {
                        print("🔐 SessionCoordinator: Failed to activate first profile: \(error)")
                        sessionState = .needsProfile
                    }
                } else {
                    sessionState = .needsProfile
                }
            }
            
        } catch let sessionError as SessionError {
            print("🔐 SessionCoordinator: Session error: \(sessionError)")
            handleError(sessionError)
            sessionState = .error
        } catch {
            print("🔐 SessionCoordinator: Unexpected error in loadUserSession: \(error)")
            handleError(.sessionLoadFailed(error.localizedDescription))
            sessionState = .error
        }
    }
    
    // MARK: - Enhanced Profile Switching
    
    func switchProfile(_ profile: SmartProfile) async throws {
        guard profile.id != activeProfile?.id else { return }
        
        // Cancel any existing switch operation
        currentSwitchTask?.cancel()
        
        // Create new switch task
        currentSwitchTask = Task {
            do {
                isSwitchingProfile = true
                profileSwitchProgress = 0.0
                
                // Phase 1: Prepare for switch (20%)
                await updateProgress(0.2)
                await prepareForProfileSwitch(from: activeProfile, to: profile)
                
                // Phase 2: Clear current session state (40%)
                await updateProgress(0.4)
                await clearCurrentProfileState()
                
                // Phase 3: Activate new profile on server (60%)
                await updateProgress(0.6)
                _ = try await profileAPI.activateProfile(profileId: profile.id)
                
                // Phase 4: Load new profile state (80%)
                await updateProgress(0.8)
                await loadProfileState(profile)
                
                // Phase 5: Finalize switch (100%)
                await updateProgress(1.0)
                activeProfile = profile
                sessionState = .authenticated
                
                // Cache the newly active profile
                cacheProfile(profile)
                
                // Update ProfileViewModel's active profile directly
                await ProfileViewModel.shared.activeProfile = profile
                
                // Notify other parts of the app
                NotificationCenter.default.post(
                    name: .profileDidChange,
                    object: nil,
                    userInfo: ["profile": profile]
                )
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
            } catch {
                if !Task.isCancelled {
                    await handleProfileSwitchError(error, targetProfile: profile)
                }
                throw error
            }
            
            isSwitchingProfile = false
            profileSwitchProgress = 0.0
        }
        
        try await currentSwitchTask?.value
    }
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.profileSwitchProgress = progress
            }
        }
    }
    
    private func prepareForProfileSwitch(from oldProfile: SmartProfile?, to newProfile: SmartProfile) async {
        // Clear sensitive data from memory
        if let oldProfile = oldProfile {
            clearProfileCache(except: [oldProfile.id, newProfile.id])
        }
        
        // Prepare new profile data if cached
        if getCachedProfile(newProfile.id) != nil {
            print("📱 Using cached profile data for \(newProfile.name)")
        }
    }
    
    private func clearCurrentProfileState() async {
        // Clear wallet connections - wait for completion
        await WalletService.shared.disconnect()
        
        // Also post notification for any other listeners
        NotificationCenter.default.post(name: .clearWalletConnections, object: nil)
        
        // Clear app-specific data
        NotificationCenter.default.post(name: .clearProfileData, object: nil)
    }
    
    private func loadProfileState(_ profile: SmartProfile) async {
        // Load profile-specific wallet state
        NotificationCenter.default.post(
            name: .loadProfileWalletState,
            object: nil,
            userInfo: ["profileId": profile.id]
        )
        
        // Initialize profile-specific services
        NotificationCenter.default.post(
            name: .initializeProfileServices,
            object: nil,
            userInfo: ["profile": profile]
        )
    }
    
    private func handleProfileSwitchError(_ error: Error, targetProfile: SmartProfile) async {
        print("❌ Profile switch failed: \(error.localizedDescription)")
        
        // Attempt to rollback if we have a previous profile
        if let previousProfile = activeProfile {
            do {
                _ = try await profileAPI.activateProfile(profileId: previousProfile.id)
                sessionState = .authenticated
            } catch {
                // Critical error - unable to restore previous state
                sessionState = .error
            }
        }
        
        handleError(.profileSwitchFailed(error.localizedDescription))
    }
    
    // MARK: - Profile Caching
    
    private struct ProfileCacheEntry {
        let profile: SmartProfile
        let timestamp: Date
        let relatedData: ProfileRelatedData?
    }
    
    private struct ProfileRelatedData {
        let linkedAccounts: [LinkedAccount]?
        let appsCount: Int?
    }
    
    private func cacheProfile(_ profile: SmartProfile) {
        profileCache[profile.id] = ProfileCacheEntry(
            profile: profile,
            timestamp: Date(),
            relatedData: nil
        )
    }
    
    private func getCachedProfile(_ profileId: String) -> SmartProfile? {
        guard let entry = profileCache[profileId],
              Date().timeIntervalSince(entry.timestamp) < cacheExpiration else {
            return nil
        }
        return entry.profile
    }
    
    private func clearProfileCache(except keepIds: [String] = []) {
        profileCache = profileCache.filter { keepIds.contains($0.key) }
    }
    
    /// Clear a specific profile from cache
    func clearProfileFromCache(profileId: String) async {
        await MainActor.run {
            profileCache.removeValue(forKey: profileId)
            print("🧹 SessionCoordinator: Cleared profile \(profileId) from cache")
        }
    }
    
    private func preloadAdjacentProfiles(current: SmartProfile, all: [SmartProfile]) async {
        // Preload profiles that user is likely to switch to
        let adjacentProfiles = all.filter { $0.id != current.id }.prefix(2)
        
        for profile in adjacentProfiles {
            cacheProfile(profile)
        }
    }
    
    // MARK: - Session Security
    
    private func handleAppBackground() {
        // Notify WalletService about app background
        WalletService.shared.handleAppBackground()
        
        // Start security timer for session timeout
        sessionSecurityTimer?.invalidate()
        sessionSecurityTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.sessionState = .locked
            }
        }
    }
    
    private func handleAppForeground() {
        // Notify WalletService about app foreground
        WalletService.shared.handleAppForeground()
        
        // Reset security timer
        resetSessionTimer()
        
        // Require biometric verification if session was locked
        if sessionState == .locked {
            Task {
                await verifyBiometricAccess()
            }
        }
    }
    
    private func handleSessionTimeout() async {
        sessionState = .locked
        NotificationCenter.default.post(name: .sessionTimedOut, object: nil)
    }
    
    func verifyBiometricAccess() async {
        // Implement biometric verification
        // For now, just unlock
        sessionState = .authenticated
    }
    
    // MARK: - Profile Management
    
    func createInitialProfile(name: String) async {
        do {
            sessionState = .loading
            
            // Check if development mode is enabled
            // Use actual development mode setting
            let isDevelopmentMode = EnvironmentConfiguration.shared.isDevelopmentModeEnabled
            
            // In V2, profiles are created automatically during authentication
            // This method is only called if something went wrong
            let isOrphanAccount = false
            
            if isOrphanAccount {
                print("🔐 SessionCoordinator: Creating first SmartProfile for orphan account")
                print("🔐 SessionCoordinator: User email: \(currentUser?.email ?? "unknown")")
            }
            
            let newProfile = try await profileAPI.createProfile(
                name: name,
                developmentMode: isDevelopmentMode
            )
            
            print("🔐 SessionCoordinator: Profile created successfully - ID: \(newProfile.id)")
            
            // If it's a development wallet, store the clientShare locally
            if let clientShare = newProfile.clientShare {
                // Store in keychain for this profile
                try? KeychainManager.shared.saveDevelopmentClientShare(
                    clientShare: clientShare,
                    profileId: newProfile.id
                )
            }
            
            // For orphan accounts, this first profile becomes their primary profile
            if isOrphanAccount {
                print("🔐 SessionCoordinator: Associated orphan account with first SmartProfile: \(newProfile.name)")
                
                // The backend should automatically associate this profile with the user
                // but we'll add a notification for any UI that needs to update
                NotificationCenter.default.post(
                    name: .orphanAccountAssociated,
                    object: nil,
                    userInfo: ["profile": newProfile, "user": currentUser as Any]
                )
            }
            
            // Activate the new profile
            try await switchProfile(newProfile)
            
        } catch {
            handleError(.profileCreationFailed(error.localizedDescription))
            sessionState = .error
        }
    }
    
    func logout() async {
        sessionState = .loading
        
        // Clear all cached data immediately and synchronously
        clearProfileCache()
        await cacheManager.clearAllCacheAsync()
        
        // Clear any errors
        error = nil
        showError = false
        
        // Disconnect wallets before logging out
        await WalletService.shared.disconnect()
        
        // Logout from auth manager (this clears keychain)
        await authManager.logout()
        
        // Clear session state
        clearSession()
    }
    
    private func handleAuthExpiry() async {
        print("🔐 SessionCoordinator: Handling authentication expiry")
        
        // Update state to show transitioning
        sessionState = .loading
        
        // Clear cached auth data immediately
        await cacheManager.clearAuthState()
        
        // Small delay for smooth transition
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Sign out and clear session
        await authManager.logout()
        clearSession()
    }
    
    private func clearSession() {
        currentUser = nil
        activeProfile = nil
        sessionState = .unauthenticated
        error = nil
        isSwitchingProfile = false
        profileSwitchProgress = 0.0
        
        // Clear any cached data
        clearProfileCache()
        
        NotificationCenter.default.post(name: .sessionDidEnd, object: nil)
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: SessionError) {
        self.error = error
        showError = true
        
        // Log error for monitoring
        print("🔴 SessionCoordinator Error: \(error.localizedDescription)")
    }
    
    func dismissError() {
        error = nil
        showError = false
    }
    
    // MARK: - Background Refresh
    
    private func refreshUserDataInBackground() async {
        // Check if we're already refreshing or if it's too soon
        guard !isRefreshingInBackground else {
            print("🔐 SessionCoordinator: Background refresh already in progress, skipping")
            return
        }
        
        if let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) < minimumRefreshInterval {
            print("🔐 SessionCoordinator: Too soon to refresh (last refresh: \(Int(Date().timeIntervalSince(lastRefresh)))s ago)")
            return
        }
        
        isRefreshingInBackground = true
        defer {
            isRefreshingInBackground = false
            lastRefreshTime = Date()
        }
        
        do {
            print("🔐 SessionCoordinator: Refreshing user data in background")
            
            // Load fresh data from API
            async let userTask = userAPI.getCurrentUser()
            async let profilesTask = profileAPI.getProfiles()
            
            let (freshUser, freshProfiles) = try await (userTask, profilesTask)
            
            // Update cache with fresh data
            cacheManager.cacheUser(freshUser)
            await cacheManager.cacheProfiles(freshProfiles)
            
            // Find the active profile
            let freshActive = freshProfiles.first(where: { $0.isActive })
            
            // Update active profile cache if needed
            if let active = freshActive,
               self.activeProfile?.updatedAt != active.updatedAt {
                await self.cacheManager.cacheActiveProfile(active)
            }
            
            // Update current data if it has changed
            if self.currentUser?.id != freshUser.id {
                // Convert fresh User to UserV2
                self.currentUser = UserV2(
                    id: freshUser.id,
                    email: freshUser.email,
                    isGuest: freshUser.isGuest
                )
            }
            
            // Update active profile if changed
            if let active = freshActive {
                if self.activeProfile?.updatedAt != active.updatedAt {
                    self.activeProfile = active
                    self.cacheProfile(active)
                }
            }
            
            print("🔐 SessionCoordinator: Background refresh completed")
        } catch {
            print("🔐 SessionCoordinator: Background refresh failed: \(error)")
            // Don't update UI - user is already using cached data
        }
    }
    
    // MARK: - Computed Properties
    
    var needsOnboarding: Bool {
        sessionState == .needsProfile
    }
    
    var isLoading: Bool {
        sessionState == .loading
    }
    
    var canProceed: Bool {
        sessionState == .authenticated && activeProfile != nil
    }
    
    var isLocked: Bool {
        sessionState == .locked
    }
}

// MARK: - Session State

enum SessionState: Equatable {
    case loading
    case unauthenticated
    case authenticated
    case needsProfile
    case locked
    case error
}

// MARK: - Session Error

enum SessionError: LocalizedError {
    case authenticationError(AuthenticationError)
    case sessionLoadFailed(String)
    case profileSwitchFailed(String)
    case profileCreationFailed(String)
    case networkError(String)
    case sessionTimeout
    case biometricFailed
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationError(let authError):
            return authError.errorDescription
        case .sessionLoadFailed(let message):
            return "Failed to load session: \(message)"
        case .profileSwitchFailed(let message):
            return "Failed to switch profile: \(message)"
        case .profileCreationFailed(let message):
            return "Failed to create profile: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .sessionTimeout:
            return "Your session has timed out. Please authenticate again."
        case .biometricFailed:
            return "Biometric authentication failed"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let profileDidChange = Notification.Name("profileDidChange")
    static let profileDidDelete = Notification.Name("profileDidDelete")
    static let sessionDidEnd = Notification.Name("sessionDidEnd")
    static let clearWalletConnections = Notification.Name("clearWalletConnections")
    static let clearProfileData = Notification.Name("clearProfileData")
    static let loadProfileWalletState = Notification.Name("loadProfileWalletState")
    static let initializeProfileServices = Notification.Name("initializeProfileServices")
    static let sessionTimedOut = Notification.Name("sessionTimedOut")
    static let orphanAccountAssociated = Notification.Name("orphanAccountAssociated")
}

