import Foundation

extension DataSyncManager {
    
    /// Override fetch method for demo mode
    func fetchDemoMode<T: Decodable>(
        type: T.Type,
        endpoint: String,
        policy: CachePolicy = .networkFirst,
        forceRefresh: Bool = false
    ) async throws -> T {
        if DemoModeConfiguration.isDemoMode {
            print("🎭 DataSyncManager: Intercepting fetch for \(endpoint)")
            
            // Add artificial delay
            try await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...200_000_000))
            
            // Route to appropriate mock data based on endpoint
            if endpoint == "profiles" {
                // Return wrapped profiles response
                if let response = ProfilesResponse(data: MockDataProvider.shared.demoProfiles, meta: nil) as? T {
                    return response
                }
            }
            
            if endpoint.contains("balance") {
                // Extract profile ID from endpoint
                let components = endpoint.split(separator: "/")
                if components.count >= 3, let profileId = components[safe: 1].map(String.init) {
                    if let balance = MockDataProvider.shared.getBalance(for: profileId) as? T {
                        return balance
                    }
                }
            }
            
            throw APIError.noData
        }
        
        // Fall back to normal fetch
        return try await fetch(type: type, endpoint: endpoint, policy: policy, forceRefresh: forceRefresh)
    }
}

// Safe array subscript extension
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// ProfilesResponse wrapper for compatibility
struct ProfilesResponse: Codable {
    let data: [SmartProfile]
    let meta: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case data
        case meta
    }
    
    init(data: [SmartProfile], meta: [String: Any]?) {
        self.data = data
        self.meta = meta
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode([SmartProfile].self, forKey: .data)
        meta = nil // Skip meta decoding for simplicity
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        // Skip meta encoding
    }
}