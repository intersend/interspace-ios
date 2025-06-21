import Foundation

// MARK: - Test Network Client
class TestNetworkClient {
    private let baseURL: String
    private let apiVersion: String
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    init(baseURL: String, apiVersion: String) {
        self.baseURL = baseURL
        self.apiVersion = apiVersion
        
        // Configure session with timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - HTTP Methods
    
    func get(
        _ endpoint: String,
        headers: [String: String]? = nil,
        queryParams: [String: String]? = nil
    ) async throws -> NetworkResponse {
        return try await request(
            method: "GET",
            endpoint: endpoint,
            headers: headers,
            queryParams: queryParams,
            body: nil
        )
    }
    
    func post(
        _ endpoint: String,
        headers: [String: String]? = nil,
        body: [String: Any]? = nil
    ) async throws -> NetworkResponse {
        return try await request(
            method: "POST",
            endpoint: endpoint,
            headers: headers,
            queryParams: nil,
            body: body
        )
    }
    
    func put(
        _ endpoint: String,
        headers: [String: String]? = nil,
        body: [String: Any]? = nil
    ) async throws -> NetworkResponse {
        return try await request(
            method: "PUT",
            endpoint: endpoint,
            headers: headers,
            queryParams: nil,
            body: body
        )
    }
    
    func delete(
        _ endpoint: String,
        headers: [String: String]? = nil
    ) async throws -> NetworkResponse {
        return try await request(
            method: "DELETE",
            endpoint: endpoint,
            headers: headers,
            queryParams: nil,
            body: nil
        )
    }
    
    // MARK: - Core Request Method
    
    private func request(
        method: String,
        endpoint: String,
        headers: [String: String]?,
        queryParams: [String: String]?,
        body: [String: Any]?
    ) async throws -> NetworkResponse {
        // Build URL
        let fullEndpoint = "/api/\(apiVersion)\(endpoint)"
        guard var components = URLComponents(string: "\(baseURL)\(fullEndpoint)") else {
            throw NetworkError.invalidURL
        }
        
        // Add query parameters
        if let queryParams = queryParams {
            components.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Interspace-iOS-TestSuite/1.0", forHTTPHeaderField: "User-Agent")
        
        // Custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Body
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        // Log request
        logRequest(request, body: body)
        
        // Execute request
        let startTime = Date()
        do {
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Log response
            logResponse(httpResponse, data: data, duration: duration)
            
            return NetworkResponse(
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields as? [String: String] ?? [:],
                data: data,
                duration: duration
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logError(error, duration: duration)
            
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    throw NetworkError.timeout
                case .notConnectedToInternet:
                    throw NetworkError.noConnection
                default:
                    throw NetworkError.requestFailed(error)
                }
            }
            
            throw NetworkError.requestFailed(error)
        }
    }
    
    // MARK: - Logging
    
    private func logRequest(_ request: URLRequest, body: [String: Any]?) {
        print("🌐 \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")")
        
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("   Headers: \(headers)")
        }
        
        if let body = body {
            print("   Body: \(body)")
        }
    }
    
    private func logResponse(_ response: HTTPURLResponse, data: Data, duration: TimeInterval) {
        let emoji = (200..<300).contains(response.statusCode) ? "✅" : "❌"
        print("\(emoji) \(response.statusCode) (\(String(format: "%.2fs", duration)))")
        
        if let json = try? JSONSerialization.jsonObject(with: data) {
            print("   Response: \(json)")
        } else if let text = String(data: data, encoding: .utf8) {
            print("   Response: \(text)")
        }
    }
    
    private func logError(_ error: Error, duration: TimeInterval) {
        print("❌ Error (\(String(format: "%.2fs", duration))): \(error.localizedDescription)")
    }
}

// MARK: - Response Model

struct NetworkResponse {
    let statusCode: Int
    let headers: [String: String]
    let data: Data?
    let duration: TimeInterval
    
    func json<T: Decodable>(as type: T.Type) throws -> T {
        guard let data = data else {
            throw NetworkError.noData
        }
        return try JSONDecoder().decode(type, from: data)
    }
    
    func jsonObject() throws -> [String: Any]? {
        guard let data = data else {
            throw NetworkError.noData
        }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case timeout
    case noConnection
    case requestFailed(Error)
    case decodingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .noData:
            return "No data received"
        case .timeout:
            return "Request timed out"
        case .noConnection:
            return "No internet connection"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}