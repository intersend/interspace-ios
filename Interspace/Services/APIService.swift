import Foundation

// MARK: - Notifications
extension Notification.Name {
    static let authenticationExpired = Notification.Name("authenticationExpired")
}

enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse(Int)
    case decodingFailed(Error)
    case apiError(String)
    case unauthorized
    case noData
    case invalidRequest(String)
}

enum HTTPMethod: String, Codable {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

class APIService {
    static let shared = APIService()
    
    // Base URL from environment configuration
    private var baseURL: URL {
        let urlString = EnvironmentConfiguration.shared.currentEnvironment.apiBaseURL
        guard let url = URL(string: urlString) else {
            fatalError("Invalid API base URL: \(urlString)")
        }
        return url
    }

    private var accessToken: String?
    private let session = URLSession.shared
    private var requestQueue: [() -> Void] = []
    private var isRefreshingToken = false
    private let queueLock = NSLock()

    private init() {
        print("🌐 APIService: Initialized")
        print("🌐 APIService: Base URL: \(baseURL.absoluteString)")
    }

    func setAccessToken(_ token: String?) {
        self.accessToken = token
    }
    
    func getAccessToken() -> String? {
        return self.accessToken
    }
    
    func clearAccessToken() {
        self.accessToken = nil
    }
    
    func getBaseURL() -> URL {
        return baseURL
    }

    // MARK: - Async/Await Methods
    
    func performRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        responseType: T.Type,
        requiresAuth: Bool = true
    ) async throws -> T {
        return try await performRequestWithRetry(
            endpoint: endpoint,
            method: method,
            body: body,
            responseType: responseType,
            requiresAuth: requiresAuth,
            retryCount: 0
        )
    }
    
    private func performRequestWithRetry<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Data?,
        responseType: T.Type,
        requiresAuth: Bool,
        retryCount: Int
    ) async throws -> T {
        // Properly construct URL handling query parameters
        let url: URL
        if endpoint.contains("?") {
            // Endpoint has query parameters
            // Split into path and query components
            let components = endpoint.split(separator: "?", maxSplits: 1)
            let pathPart = String(components[0])
            let queryPart = components.count > 1 ? String(components[1]) : ""
            
            // Build URL using URLComponents to properly handle encoding
            guard var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
                throw APIError.invalidURL
            }
            
            // Append path to existing path
            urlComponents.path = (urlComponents.path.hasSuffix("/") ? urlComponents.path : urlComponents.path + "/") + pathPart
            
            // Set query string directly (it should already be properly formatted)
            if !queryPart.isEmpty {
                urlComponents.query = queryPart
            }
            
            guard let fullURL = urlComponents.url else {
                throw APIError.invalidURL
            }
            url = fullURL
        } else {
            // No query parameters, use normal appending
            url = baseURL.appendingPathComponent(endpoint)
        }
        
        #if DEBUG
        print("🌐 APIService: Making \(method.rawValue) request to: \(url.absoluteString)")
        #endif
        
        // Notify debug overlay
        // TODO: Uncomment when EnvironmentConfiguration is added
        // NotificationCenter.default.post(name: .apiCallMade, object: nil)
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0 // 30 seconds timeout
        
        // Add ngrok headers if using ngrok URL
        if url.absoluteString.contains("ngrok") {
            request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        }

        // Add authorization header if required and available
        if requiresAuth {
            // Always get the latest token in case it was refreshed
            if let token = self.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                #if DEBUG
                print("🌐 APIService: Added auth header for \(endpoint)")
                if retryCount > 0 {
                    print("🌐 APIService: This is a retry request (attempt \(retryCount + 1))")
                    print("🌐 APIService: Token being used (prefix): \(String(token.prefix(20)))")
                }
                #endif
            } else {
                #if DEBUG
                print("🔴 APIService: No access token available for authenticated request to \(endpoint)")
                #endif
            }
        }

        if let body = body {
            request.httpBody = body
            
            #if DEBUG
            if endpoint.contains("link-accounts") {
                if let jsonString = String(data: body, encoding: .utf8) {
                    print("🌐 APIService: Request body for \(endpoint): \(jsonString)")
                }
            }
            #endif
        }

        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse(0)
            }
            
            #if DEBUG
            print("🌐 APIService: Response status: \(httpResponse.statusCode)")
            #endif
            
            switch httpResponse.statusCode {
            case 200...299:
                #if DEBUG
                print("🌐 APIService: Request successful")
                #endif
                break
            case 401:
                // Token expired, try to refresh if this is the first retry
                if requiresAuth && retryCount == 0 {
                    #if DEBUG
                    print("🌐 APIService: Got 401, attempting token refresh for \(endpoint)")
                    #endif
                    
                    // Request token refresh from AuthenticationManager
                    await AuthenticationManagerV2.shared.refreshTokenIfNeeded()
                    
                    // Check if we still have a valid token after refresh attempt
                    if let newToken = self.accessToken {
                        #if DEBUG
                        print("🌐 APIService: Token refresh successful, retrying request to \(endpoint)")
                        print("🌐 APIService: New token prefix: \(String(newToken.prefix(20)))")
                        #endif
                        
                        // Retry the request with new token
                        return try await performRequestWithRetry(
                            endpoint: endpoint,
                            method: method,
                            body: body,
                            responseType: responseType,
                            requiresAuth: requiresAuth,
                            retryCount: retryCount + 1
                        )
                    } else {
                        #if DEBUG
                        print("🌐 APIService: Token refresh failed - no token available")
                        #endif
                    }
                }
                
                // If refresh failed or this is a retry, clear token and notify about auth expiry
                #if DEBUG
                print("🌐 APIService: Authentication failed for \(endpoint), posting expiry notification")
                #endif
                
                // Clear the access token to prevent further failed requests
                self.accessToken = nil
                
                // Notify about auth expiry
                await MainActor.run {
                    NotificationCenter.default.post(name: .authenticationExpired, object: nil)
                }
                throw APIError.unauthorized
            case 403:
                // Forbidden - user doesn't have permission
                // This usually means the token is valid but lacks required permissions
                await MainActor.run {
                    NotificationCenter.default.post(name: .authenticationExpired, object: nil)
                }
                throw APIError.unauthorized
            default:
                #if DEBUG
                print("🌐 APIService: Request failed with status: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🌐 APIService: Error response body: \(responseString)")
                }
                #endif
                
                // Try to decode error message
                if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    // For 5xx errors that are actually client errors (like invalid verification code)
                    // treat them as API errors with the message
                    if httpResponse.statusCode >= 500 && errorData.errorMessage.lowercased().contains("invalid") {
                        throw APIError.apiError(errorData.errorMessage)
                    }
                    throw APIError.apiError(errorData.errorMessage)
                }
                
                // If we can't decode the error, try to get the raw response
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                print("🔴 APIService: Failed to parse error response: \(responseString)")
                
                // For 5xx errors, provide a more user-friendly message
                if httpResponse.statusCode >= 500 {
                    throw APIError.apiError("Server error. Please try again.")
                }
                
                throw APIError.invalidResponse(httpResponse.statusCode)
            }

            // Handle empty responses
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            
            guard !data.isEmpty else {
                throw APIError.noData
            }

            do {
                #if DEBUG
                print("🌐 APIService: Attempting to decode response of type: \(T.self)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🌐 APIService: Raw response: \(responseString)")
                }
                #endif
                
                let decodedObject = try JSONDecoder().decode(T.self, from: data)
                
                #if DEBUG
                print("🌐 APIService: Successfully decoded response")
                #endif
                
                return decodedObject
            } catch {
                #if DEBUG
                print("🔴 APIService: Decoding error: \(error)")
                print("🔴 APIService: Expected type: \(T.self)")
                print("🔴 APIService: Response data: \(String(data: data, encoding: .utf8) ?? "Unable to convert to string")")
                #endif
                throw APIError.decodingFailed(error)
            }
        } catch {
            if error is APIError {
                throw error
            }
            throw APIError.requestFailed(error)
        }
    }

    // MARK: - Legacy Completion Handler Methods (for backward compatibility)
    
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        Task {
            do {
                let httpMethod = HTTPMethod(rawValue: method) ?? .GET
                let result: T = try await performRequest(
                    endpoint: endpoint,
                    method: httpMethod,
                    body: body,
                    responseType: T.self
                )
                completion(.success(result))
            } catch {
                completion(.failure(error as? APIError ?? APIError.requestFailed(error)))
            }
        }
    }
}

// MARK: - Response Models

struct APIErrorResponse: Codable {
    let success: Bool?
    let message: String?
    let error: String?
    let statusCode: Int?
    let code: String?
    let errorCode: String?  // Backend sends specific error codes
    
    // Get the actual error message from either field
    var errorMessage: String {
        return message ?? error ?? "Unknown error"
    }
}

struct EmptyResponse: Codable {
    init() {}
}
