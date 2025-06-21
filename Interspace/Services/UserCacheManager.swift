import Foundation
import SwiftUI

// Type alias for profile compatibility
typealias Profile = SmartProfile

/// Manages caching of user data for instant app launches
@MainActor
class UserCacheManager: ObservableObject {
    static let shared = UserCacheManager()
    
    private let cacheQueue = DispatchQueue(label: "com.interspace.cache", attributes: .concurrent)
    private let userDefaults = UserDefaults.standard
    
    // Cache keys
    private let userCacheKey = "com.interspace.user.cache"
    private let profilesCacheKey = "com.interspace.profiles.cache"
    private let activeProfileCacheKey = "com.interspace.activeProfile.cache"
    private let authStateCacheKey = "com.interspace.authState.cache"
    private let cacheTimestampKey = "com.interspace.cache.timestamp"
    private let cacheVersionKey = "com.interspace.cache.version"
    
    // Current cache version - increment this when making breaking changes
    private let currentCacheVersion = 2
    
    // Cache expiration (24 hours for user data, 1 hour for auth state)
    private let userDataCacheExpiration: TimeInterval = 24 * 60 * 60
    private let authStateCacheExpiration: TimeInterval = 60 * 60
    
    private init() {}
    
    // MARK: - User Data Caching
    
    /// Cache user data for instant launch
    func cacheUser(_ user: User) {
        cacheQueue.async(flags: .barrier) {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(user)
                self.userDefaults.set(data, forKey: self.userCacheKey)
                self.updateCacheTimestamp()
                print("💾 Cached user data")
            } catch {
                print("❌ Failed to cache user: \(error)")
            }
        }
    }
    
    /// Get cached user data if valid
    func getCachedUser() -> User? {
        guard isCacheValid(for: userDataCacheExpiration) else {
            print("💾 User cache expired")
            return nil
        }
        
        guard let data = userDefaults.data(forKey: userCacheKey) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let user = try decoder.decode(User.self, from: data)
            print("💾 Retrieved cached user")
            return user
        } catch {
            print("❌ Failed to decode cached user: \(error)")
            return nil
        }
    }
    
    // MARK: - Profile Data Caching
    
    /// Cache profiles data
    func cacheProfiles(_ profiles: [Profile]) {
        cacheQueue.async(flags: .barrier) {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(profiles)
                self.userDefaults.set(data, forKey: self.profilesCacheKey)
                print("💾 Cached \(profiles.count) profiles")
            } catch {
                print("❌ Failed to cache profiles: \(error)")
            }
        }
    }
    
    /// Get cached profiles
    func getCachedProfiles() -> [Profile]? {
        guard isCacheValid(for: userDataCacheExpiration) else {
            return nil
        }
        
        guard let data = userDefaults.data(forKey: profilesCacheKey) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let profiles = try decoder.decode([Profile].self, from: data)
            print("💾 Retrieved \(profiles.count) cached profiles")
            return profiles
        } catch {
            print("❌ Failed to decode cached profiles: \(error)")
            return nil
        }
    }
    
    /// Cache active profile
    func cacheActiveProfile(_ profile: Profile?) {
        cacheQueue.async(flags: .barrier) {
            if let profile = profile {
                do {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(profile)
                    self.userDefaults.set(data, forKey: self.activeProfileCacheKey)
                    print("💾 Cached active profile: \(profile.name)")
                } catch {
                    print("❌ Failed to cache active profile: \(error)")
                }
            } else {
                self.userDefaults.removeObject(forKey: self.activeProfileCacheKey)
            }
        }
    }
    
    /// Get cached active profile
    func getCachedActiveProfile() -> Profile? {
        guard isCacheValid(for: userDataCacheExpiration) else {
            return nil
        }
        
        guard let data = userDefaults.data(forKey: activeProfileCacheKey) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let profile = try decoder.decode(Profile.self, from: data)
            print("💾 Retrieved cached active profile: \(profile.name)")
            return profile
        } catch {
            print("❌ Failed to decode cached active profile: \(error)")
            return nil
        }
    }
    
    // MARK: - Auth State Caching
    
    /// Cache authentication state for quick session restoration
    func cacheAuthState(isAuthenticated: Bool, token: String?) {
        cacheQueue.async(flags: .barrier) {
            let authState = AuthStateCache(
                isAuthenticated: isAuthenticated,
                token: token,
                timestamp: Date()
            )
            
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(authState)
                self.userDefaults.set(data, forKey: self.authStateCacheKey)
                print("💾 Cached auth state")
            } catch {
                print("❌ Failed to cache auth state: \(error)")
            }
        }
    }
    
    /// Get cached auth state if valid
    func getCachedAuthState() -> (isAuthenticated: Bool, token: String?)? {
        guard let data = userDefaults.data(forKey: authStateCacheKey) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let authState = try decoder.decode(AuthStateCache.self, from: data)
            
            // Check if auth cache is still valid (1 hour)
            let age = Date().timeIntervalSince(authState.timestamp)
            if age > authStateCacheExpiration {
                print("💾 Auth cache expired")
                return nil
            }
            
            print("💾 Retrieved cached auth state")
            return (authState.isAuthenticated, authState.token)
        } catch {
            print("❌ Failed to decode cached auth state: \(error)")
            return nil
        }
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached data
    func clearAllCache() {
        cacheQueue.async(flags: .barrier) {
            self.userDefaults.removeObject(forKey: self.userCacheKey)
            self.userDefaults.removeObject(forKey: self.profilesCacheKey)
            self.userDefaults.removeObject(forKey: self.activeProfileCacheKey)
            self.userDefaults.removeObject(forKey: self.authStateCacheKey)
            self.userDefaults.removeObject(forKey: self.cacheTimestampKey)
            self.userDefaults.synchronize()
            print("💾 Cleared all cache")
        }
    }
    
    /// Clear all cached data asynchronously with completion
    func clearAllCacheAsync() async {
        await withCheckedContinuation { continuation in
            cacheQueue.async(flags: .barrier) {
                self.userDefaults.removeObject(forKey: self.userCacheKey)
                self.userDefaults.removeObject(forKey: self.profilesCacheKey)
                self.userDefaults.removeObject(forKey: self.activeProfileCacheKey)
                self.userDefaults.removeObject(forKey: self.authStateCacheKey)
                self.userDefaults.removeObject(forKey: self.cacheTimestampKey)
                self.userDefaults.synchronize()
                print("💾 Cleared all cache (async)")
                continuation.resume()
            }
        }
    }
    
    /// Clear only authentication state cache
    func clearAuthState() async {
        await withCheckedContinuation { continuation in
            cacheQueue.async(flags: .barrier) {
                self.userDefaults.removeObject(forKey: self.authStateCacheKey)
                // Also mark user data as stale by backdating timestamp
                if let _ = self.userDefaults.object(forKey: self.cacheTimestampKey) {
                    let staleDate = Date().addingTimeInterval(-self.userDataCacheExpiration - 1)
                    self.userDefaults.set(staleDate, forKey: self.cacheTimestampKey)
                }
                print("💾 Cleared auth state cache")
                continuation.resume()
            }
        }
    }
    
    /// Invalidate cache for specific data types when auth fails
    func invalidateOnAuthFailure() {
        cacheQueue.async(flags: .barrier) {
            // Clear auth state immediately
            self.userDefaults.removeObject(forKey: self.authStateCacheKey)
            
            // Mark all cached data as potentially stale
            let staleDate = Date().addingTimeInterval(-60) // 1 minute ago
            self.userDefaults.set(staleDate, forKey: self.cacheTimestampKey)
            
            print("💾 Invalidated cache due to auth failure")
        }
    }
    
    /// Clear expired cache
    func clearExpiredCache() {
        if !isCacheValid(for: userDataCacheExpiration) {
            clearAllCache()
        }
    }
    
    /// Check if cache is valid based on timestamp and version
    private func isCacheValid(for duration: TimeInterval) -> Bool {
        // Check cache version first
        let storedVersion = userDefaults.integer(forKey: cacheVersionKey)
        if storedVersion != currentCacheVersion {
            print("💾 Cache version mismatch - stored: \(storedVersion), current: \(currentCacheVersion)")
            return false
        }
        
        guard let timestamp = userDefaults.object(forKey: cacheTimestampKey) as? Date else {
            return false
        }
        
        let age = Date().timeIntervalSince(timestamp)
        return age < duration
    }
    
    /// Update cache timestamp
    private func updateCacheTimestamp() {
        userDefaults.set(Date(), forKey: cacheTimestampKey)
        userDefaults.set(currentCacheVersion, forKey: cacheVersionKey)
    }
    
    /// Preload cache data for quick access
    func preloadCache() async -> (user: User?, profiles: [Profile]?, activeProfile: Profile?, isAuthenticated: Bool) {
        return await withCheckedContinuation { continuation in
            cacheQueue.async {
                let user = self.getCachedUser()
                let profiles = self.getCachedProfiles()
                let activeProfile = self.getCachedActiveProfile()
                let authState = self.getCachedAuthState()
                
                continuation.resume(returning: (
                    user: user,
                    profiles: profiles,
                    activeProfile: activeProfile,
                    isAuthenticated: authState?.isAuthenticated ?? false
                ))
            }
        }
    }
}

// MARK: - Auth State Cache Model

private struct AuthStateCache: Codable {
    let isAuthenticated: Bool
    let token: String?
    let timestamp: Date
}