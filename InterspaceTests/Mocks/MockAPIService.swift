import Foundation
@testable import Interspace

class MockAPIService: APIService {
    var mockResponses: [String: Any] = [:]
    var mockErrors: [String: Error] = [:]
    var requestHistory: [(endpoint: String, method: HTTPMethod, body: Data?)] = []
    var shouldFailNextRequest = false
    var delayInSeconds: TimeInterval = 0
    
    override func performRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        responseType: T.Type,
        requiresAuth: Bool = true
    ) async throws -> T {
        // Record the request
        requestHistory.append((endpoint: endpoint, method: method, body: body))
        
        // Simulate network delay if needed
        if delayInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
        }
        
        // Check if should fail
        if shouldFailNextRequest {
            shouldFailNextRequest = false
            throw APIError.networkError("Mock network failure")
        }
        
        // Check for mock error
        if let error = mockErrors[endpoint] {
            throw error
        }
        
        // Check for mock response
        if let response = mockResponses[endpoint] {
            if let typedResponse = response as? T {
                return typedResponse
            } else if let data = response as? Data {
                return try JSONDecoder().decode(T.self, from: data)
            }
        }
        
        // Default empty response for certain types
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        
        throw APIError.noData
    }
    
    func reset() {
        mockResponses.removeAll()
        mockErrors.removeAll()
        requestHistory.removeAll()
        shouldFailNextRequest = false
        delayInSeconds = 0
    }
    
    func verifyRequest(endpoint: String, method: HTTPMethod, callCount: Int = 1) -> Bool {
        let matches = requestHistory.filter { $0.endpoint == endpoint && $0.method == method }
        return matches.count == callCount
    }
    
    func getLastRequestBody<T: Decodable>(for endpoint: String, as type: T.Type) -> T? {
        guard let lastRequest = requestHistory.last(where: { $0.endpoint == endpoint }),
              let body = lastRequest.body else {
            return nil
        }
        
        return try? JSONDecoder().decode(T.self, from: body)
    }
}