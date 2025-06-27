import Foundation
import Combine
import CoreData
import UIKit

// MARK: - Cache Policy

enum CachePolicy {
    case networkOnly              // Always fetch from network
    case cacheFirst              // Use cache if available, network as fallback
    case networkFirst            // Try network first, cache as fallback
    case cacheOnly               // Only use cache, fail if not available
    case cacheAndNetwork         // Return cache immediately, update with network
}

// MARK: - Cache Entry Protocol

protocol CacheEntry {
    var id: String { get }
    var timestamp: Date { get }
    var expirationDate: Date { get }
    var checksum: String? { get }
}

// MARK: - Data Sync Manager

@MainActor
final class DataSyncManager: ObservableObject {
    static let shared = DataSyncManager()
    
    // MARK: - Published Properties
    
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0.0
    @Published var lastSyncDate: Date?
    @Published var pendingOperations: Int = 0
    
    // MARK: - Private Properties
    
    private let cacheManager: CacheStorageManager
    private let apiService = APIService.shared
    private let keychainManager = KeychainManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Background sync
    private var backgroundSyncTimer: Timer?
    private let backgroundSyncQueue = DispatchQueue(label: "com.interspace.datasync", qos: .background)
    
    // Offline queue
    private var offlineOperationQueue: [OfflineOperation] = []
    private let offlineQueueLock = NSLock()
    
    // Cache policies per data type
    private let cachePolicies: [String: CachePolicy] = [
        "User": .cacheAndNetwork,
        "Profile": .cacheAndNetwork,
        "Apps": .cacheFirst,
        "Balance": .networkFirst,
        "TransactionHistory": .cacheFirst
    ]
    
    // Cache expiration times (in seconds)
    private let cacheExpirations: [String: TimeInterval] = [
        "User": 14400,      // 4 hours
        "Profile": 14400,   // 4 hours
        "Apps": 86400,      // 24 hours
        "Balance": 300,     // 5 minutes
        "TransactionHistory": 3600  // 1 hour
    ]
    
    // MARK: - Initialization
    
    private init() {
        self.cacheManager = CacheStorageManager()
        setupBindings()
        setupBackgroundSync()
        loadOfflineQueue()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Monitor network connectivity
        NotificationCenter.default.publisher(for: .networkStatusChanged)
            .sink { [weak self] notification in
                if let isConnected = notification.object as? Bool, isConnected {
                    Task {
                        try? await self?.syncOfflineQueue()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Monitor app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.performBackgroundSync()
                }
            }
            .store(in: &cancellables)
        
        // Monitor profile changes
        NotificationCenter.default.publisher(for: .profileDidChange)
            .sink { [weak self] _ in
                self?.invalidateProfileRelatedCache()
            }
            .store(in: &cancellables)
    }
    
    private func setupBackgroundSync() {
        backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task {
                await self?.performBackgroundSync()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetch demo data for demo mode
    func fetchDemoMode<T: Codable>(
        endpoint: String,
        type: T.Type,
        cacheKey: String,
        forceRefresh: Bool = false,
        policy: CachePolicy = .cacheFirst
    ) async throws -> T {
        // Return mock data based on the endpoint
        if endpoint.contains("user") {
            let user = User(
                id: "demo-user-1",
                email: "demo@interspace.app",
                walletAddress: nil,
                isGuest: false,
                authStrategies: ["email"],
                profilesCount: 2,
                linkedAccountsCount: 1,
                activeDevicesCount: 1,
                socialAccounts: [],
                createdAt: Date().ISO8601Format(),
                updatedAt: Date().ISO8601Format()
            )
            let userData = UserResponse(
                success: true,
                data: user
            )
            if let result = userData as? T {
                return result
            }
        }
        
        // Default empty response
        throw NSError(domain: "DemoMode", code: 404, userInfo: [NSLocalizedDescriptionKey: "Demo data not available for this endpoint"])
    }
    
    /// Fetch data with specified cache policy
    func fetch<T: Codable>(
        type: T.Type,
        endpoint: String,
        policy: CachePolicy? = nil,
        forceRefresh: Bool = false,
        requiresAuth: Bool = true
    ) async throws -> T {
        let typeName = String(describing: type)
        let effectivePolicy = forceRefresh ? .networkOnly : (policy ?? cachePolicies[typeName] ?? .networkFirst)
        
        switch effectivePolicy {
        case .networkOnly:
            return try await fetchFromNetwork(type: type, endpoint: endpoint, requiresAuth: requiresAuth)
            
        case .cacheFirst:
            if let cached = try? await fetchFromCache(type: type, key: endpoint) {
                // Async update from network if needed
                Task {
                    try? await updateCacheFromNetwork(type: type, endpoint: endpoint, requiresAuth: requiresAuth)
                }
                return cached
            }
            return try await fetchFromNetwork(type: type, endpoint: endpoint, requiresAuth: requiresAuth)
            
        case .networkFirst:
            do {
                return try await fetchFromNetwork(type: type, endpoint: endpoint, requiresAuth: requiresAuth)
            } catch {
                if let cached = try? await fetchFromCache(type: type, key: endpoint) {
                    return cached
                }
                throw error
            }
            
        case .cacheOnly:
            guard let cached = try? await fetchFromCache(type: type, key: endpoint) else {
                throw DataSyncError.noCachedData
            }
            return cached
            
        case .cacheAndNetwork:
            // Return cache immediately if available
            if let cached = try? await fetchFromCache(type: type, key: endpoint) {
                // Update from network in background
                Task {
                    try? await updateCacheFromNetwork(type: type, endpoint: endpoint, requiresAuth: requiresAuth)
                }
                return cached
            }
            // No cache, fetch from network
            return try await fetchFromNetwork(type: type, endpoint: endpoint, requiresAuth: requiresAuth)
        }
    }
    
    /// Prefetch multiple data types
    func prefetch<T: Codable>(
        types: [(type: T.Type, endpoint: String)],
        policy: CachePolicy = .networkFirst
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for item in types {
                group.addTask {
                    try? await self.fetch(
                        type: item.type,
                        endpoint: item.endpoint,
                        policy: policy,
                        forceRefresh: false
                    )
                }
            }
        }
    }
    
    /// Invalidate cache for specific type or ID
    func invalidate(type: Any.Type? = nil, id: String? = nil) {
        if let type = type {
            let typeName = String(describing: type)
            cacheManager.invalidate(type: typeName, id: id)
        } else {
            cacheManager.invalidateAll()
        }
    }
    
    /// Add operation to offline queue
    func queueOfflineOperation(
        endpoint: String,
        method: HTTPMethod,
        body: Data?,
        description: String
    ) {
        offlineQueueLock.lock()
        defer { offlineQueueLock.unlock() }
        
        let operation = OfflineOperation(
            id: UUID().uuidString,
            endpoint: endpoint,
            method: method,
            body: body,
            description: description,
            timestamp: Date(),
            retryCount: 0
        )
        
        offlineOperationQueue.append(operation)
        pendingOperations = offlineOperationQueue.count
        saveOfflineQueue()
    }
    
    /// Sync all pending offline operations
    func syncOfflineQueue() async throws {
        guard !offlineOperationQueue.isEmpty else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        var failedOperations: [OfflineOperation] = []
        let total = offlineOperationQueue.count
        
        for (index, operation) in offlineOperationQueue.enumerated() {
            syncProgress = Double(index) / Double(total)
            
            do {
                try await executeOfflineOperation(operation)
            } catch {
                var updatedOperation = operation
                updatedOperation.retryCount += 1
                updatedOperation.lastError = error.localizedDescription
                
                if updatedOperation.retryCount < 3 {
                    failedOperations.append(updatedOperation)
                }
            }
        }
        
        offlineQueueLock.lock()
        offlineOperationQueue = failedOperations
        pendingOperations = offlineOperationQueue.count
        offlineQueueLock.unlock()
        
        saveOfflineQueue()
        syncProgress = 1.0
        lastSyncDate = Date()
    }
    
    // MARK: - Private Methods
    
    private func fetchFromNetwork<T: Codable>(
        type: T.Type,
        endpoint: String,
        requiresAuth: Bool
    ) async throws -> T {
        // Handle wrapped responses for specific endpoints
        if endpoint.contains("/balance") && type == UnifiedBalance.self {
            let response = try await apiService.performRequest(
                endpoint: endpoint,
                method: .GET,
                responseType: BalanceResponse.self,
                requiresAuth: requiresAuth
            )
            let data = response.data as! T
            try await cacheData(data, type: type, key: endpoint)
            return data
        } else if endpoint == "profiles" && type == ProfilesResponse.self {
            // For profiles endpoint, fetch the wrapped response directly
            let data = try await apiService.performRequest(
                endpoint: endpoint,
                method: .GET,
                responseType: type,
                requiresAuth: requiresAuth
            )
            try await cacheData(data, type: type, key: endpoint)
            return data
        } else if endpoint.contains("/apps") && type == AppsResponse.self {
            // For apps endpoint, fetch the wrapped response directly
            let data = try await apiService.performRequest(
                endpoint: endpoint,
                method: .GET,
                responseType: type,
                requiresAuth: requiresAuth
            )
            try await cacheData(data, type: type, key: endpoint)
            return data
        } else {
            // Default behavior for other endpoints
            let data = try await apiService.performRequest(
                endpoint: endpoint,
                method: .GET,
                responseType: type,
                requiresAuth: requiresAuth
            )
            try await cacheData(data, type: type, key: endpoint)
            return data
        }
    }
    
    private func fetchFromCache<T: Codable>(
        type: T.Type,
        key: String
    ) async throws -> T? {
        return try await cacheManager.retrieve(type: type, key: key)
    }
    
    private func cacheData<T: Codable>(
        _ data: T,
        type: T.Type,
        key: String
    ) async throws {
        let typeName = String(describing: type)
        let expiration = cacheExpirations[typeName] ?? 3600
        
        try await cacheManager.store(
            data,
            type: type,
            key: key,
            expiration: expiration
        )
    }
    
    private func updateCacheFromNetwork<T: Codable>(
        type: T.Type,
        endpoint: String,
        requiresAuth: Bool
    ) async throws {
        let data = try await fetchFromNetwork(
            type: type,
            endpoint: endpoint,
            requiresAuth: requiresAuth
        )
        
        // Notify observers of data update
        NotificationCenter.default.post(
            name: .dataDidUpdate,
            object: nil,
            userInfo: ["type": String(describing: type), "data": data]
        )
    }
    
    private func performBackgroundSync() async {
        guard !isSyncing else { return }
        
        // Validate auth token before any sync operations
        guard await AuthenticationManagerV2.shared.validateAuthToken() else {
            print("🔄 DataSyncManager: Skipping background sync - invalid auth token")
            return
        }
        
        // Move sync operations to background context
        await Task.detached(priority: .background) {
            print("🔄 DataSyncManager: Starting background sync")
            
            // Update sync state on main actor
            await MainActor.run {
                self.isSyncing = true
                self.syncProgress = 0.0
            }
            
            // Sync based on current session state
            if let activeProfile = await SessionCoordinator.shared.activeProfile {
                // Prefetch common data with staggered requests to prevent UI lag
                async let userFetch: Void = self.fetchInBackground(type: UserResponse.self, endpoint: "users/me", policy: .cacheAndNetwork)
                async let profilesFetch: Void = self.fetchInBackground(type: ProfilesResponse.self, endpoint: "profiles", policy: .cacheAndNetwork)
                
                // Small delay between requests to prevent overwhelming the system
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                async let appsFetch: Void = self.fetchInBackground(type: AppsResponse.self, endpoint: "profiles/\(activeProfile.id)/apps", policy: .cacheFirst)
                
                // Wait for all fetches to complete
                _ = await (userFetch, profilesFetch, appsFetch)
            }
            
            // Sync offline queue if network available
            if NetworkMonitor.shared.isConnected {
                try? await self.syncOfflineQueue()
            }
            
            // Update state on main actor
            await MainActor.run {
                self.isSyncing = false
                self.syncProgress = 1.0
                self.lastSyncDate = Date()
            }
            
            print("🔄 DataSyncManager: Background sync completed")
        }.value
    }
    
    /// Helper method to fetch data in background context
    private func fetchInBackground<T: Codable>(type: T.Type, endpoint: String, policy: CachePolicy) async {
        do {
            _ = try await fetch(type: type, endpoint: endpoint, policy: policy)
        } catch {
            print("🔄 DataSyncManager: Background fetch failed for \(endpoint): \(error)")
        }
    }
    
    private func invalidateProfileRelatedCache() {
        invalidate(type: BookmarkedApp.self)
        invalidate(type: UnifiedBalance.self)
        invalidate(type: TransactionHistory.self)
    }
    
    private func executeOfflineOperation(_ operation: OfflineOperation) async throws {
        let _: EmptyResponse = try await apiService.performRequest(
            endpoint: operation.endpoint,
            method: operation.method,
            body: operation.body,
            responseType: EmptyResponse.self,
            requiresAuth: true
        )
    }
    
    private func loadOfflineQueue() {
        if let data = UserDefaults.standard.data(forKey: "com.interspace.offlineQueue"),
           let operations = try? JSONDecoder().decode([OfflineOperation].self, from: data) {
            offlineOperationQueue = operations
            pendingOperations = operations.count
        }
    }
    
    private func saveOfflineQueue() {
        if let data = try? JSONEncoder().encode(offlineOperationQueue) {
            UserDefaults.standard.set(data, forKey: "com.interspace.offlineQueue")
        }
    }
}

// MARK: - Supporting Types

enum DataSyncError: LocalizedError {
    case noCachedData
    case cacheExpired
    case syncFailed(String)
    case offlineQueueFull
    
    var errorDescription: String? {
        switch self {
        case .noCachedData:
            return "No cached data available"
        case .cacheExpired:
            return "Cache has expired"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .offlineQueueFull:
            return "Offline queue is full"
        }
    }
}

struct OfflineOperation: Codable {
    let id: String
    let endpoint: String
    let method: HTTPMethod
    let body: Data?
    let description: String
    let timestamp: Date
    var retryCount: Int
    var lastError: String?
}

// MARK: - Notifications

extension Notification.Name {
    static let dataDidUpdate = Notification.Name("dataDidUpdate")
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}