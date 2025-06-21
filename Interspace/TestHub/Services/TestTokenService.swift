import Foundation

// MARK: - Test Token Service
class TestTokenService: ObservableObject {
    private let apiService: APIService
    private let configuration: TestConfiguration
    
    init(apiService: APIService, configuration: TestConfiguration) {
        self.apiService = apiService
        self.configuration = configuration
    }
    
    // MARK: - Token Refresh Test
    
    func testTokenRefresh(refreshToken: String) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        details.refreshToken = refreshToken
        
        do {
            let endpoint = "/api/\(configuration.apiVersion)/auth/refresh"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "POST"
            
            let params: [String: Any] = [
                "refreshToken": refreshToken
            ]
            
            let data = try await apiService.request(
                endpoint: endpoint,
                method: .post,
                parameters: params
            )
            
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = response["success"] as? Bool ?? false
                let tokens = response["tokens"] as? [String: Any]
                let newAccessToken = tokens?["accessToken"] as? String
                let newRefreshToken = tokens?["refreshToken"] as? String
                
                details.accessToken = newAccessToken
                details.refreshToken = newRefreshToken
                
                let hasNewTokens = newAccessToken != nil && newRefreshToken != nil
                let validationSuccess = success && hasNewTokens
                
                return TestResult(
                    testName: "Token Refresh",
                    category: TestCategory.tokenManagement.rawValue,
                    success: validationSuccess,
                    message: validationSuccess ? "Successfully refreshed tokens" : "Token refresh validation failed",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details
                )
            } else {
                throw TestError(code: "PARSE_ERROR", message: "Failed to parse refresh response")
            }
        } catch {
            return TestResult(
                testName: "Token Refresh",
                category: TestCategory.tokenManagement.rawValue,
                success: false,
                message: "Failed to refresh token",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "REFRESH_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Token Validation Test
    
    func testTokenValidation(accessToken: String) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        details.accessToken = accessToken
        
        do {
            // Use a protected endpoint to validate the token
            let endpoint = "/api/\(configuration.apiVersion)/profiles"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "GET"
            
            let data = try await apiService.request(
                endpoint: endpoint,
                method: .get,
                headers: ["Authorization": "Bearer \(accessToken)"]
            )
            
            // If we get a successful response, the token is valid
            details.responseStatusCode = 200
            
            return TestResult(
                testName: "Token Validation",
                category: TestCategory.tokenManagement.rawValue,
                success: true,
                message: "Access token is valid",
                executionTime: Date().timeIntervalSince(startTime),
                details: details
            )
        } catch {
            // Check if it's an authentication error
            if let apiError = error as? APIError {
                details.responseStatusCode = apiError.statusCode
                
                if apiError.statusCode == 401 {
                    return TestResult(
                        testName: "Token Validation",
                        category: TestCategory.tokenManagement.rawValue,
                        success: false,
                        message: "Access token is invalid or expired",
                        executionTime: Date().timeIntervalSince(startTime),
                        details: details,
                        error: TestError(code: "INVALID_TOKEN", message: "Token validation failed")
                    )
                }
            }
            
            return TestResult(
                testName: "Token Validation",
                category: TestCategory.tokenManagement.rawValue,
                success: false,
                message: "Token validation request failed",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "VALIDATION_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Token Expiration Test
    
    func testTokenExpiration(expiredToken: String) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        details.accessToken = expiredToken
        
        do {
            // Try to use an expired token
            let endpoint = "/api/\(configuration.apiVersion)/profiles"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "GET"
            
            let _ = try await apiService.request(
                endpoint: endpoint,
                method: .get,
                headers: ["Authorization": "Bearer \(expiredToken)"]
            )
            
            // If we get here, the token was NOT expired (unexpected)
            return TestResult(
                testName: "Token Expiration",
                category: TestCategory.tokenManagement.rawValue,
                success: false,
                message: "Expected token to be expired but request succeeded",
                executionTime: Date().timeIntervalSince(startTime),
                details: details
            )
        } catch {
            // We expect this to fail with 401
            if let apiError = error as? APIError,
               apiError.statusCode == 401 {
                return TestResult(
                    testName: "Token Expiration",
                    category: TestCategory.tokenManagement.rawValue,
                    success: true,
                    message: "Correctly rejected expired token",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details
                )
            }
            
            return TestResult(
                testName: "Token Expiration",
                category: TestCategory.tokenManagement.rawValue,
                success: false,
                message: "Unexpected error when testing expired token",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "UNEXPECTED_ERROR", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Token Blacklist Test
    
    func testTokenBlacklist(token: String) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        details.accessToken = token
        
        do {
            // First, logout to blacklist the token
            let logoutEndpoint = "/api/\(configuration.apiVersion)/auth/logout"
            let _ = try await apiService.request(
                endpoint: logoutEndpoint,
                method: .post,
                headers: ["Authorization": "Bearer \(token)"]
            )
            
            // Now try to use the blacklisted token
            let testEndpoint = "/api/\(configuration.apiVersion)/profiles"
            details.requestURL = configuration.baseURL + testEndpoint
            details.requestMethod = "GET"
            
            do {
                let _ = try await apiService.request(
                    endpoint: testEndpoint,
                    method: .get,
                    headers: ["Authorization": "Bearer \(token)"]
                )
                
                // If we get here, the token was NOT blacklisted (unexpected)
                return TestResult(
                    testName: "Token Blacklist",
                    category: TestCategory.tokenManagement.rawValue,
                    success: false,
                    message: "Expected token to be blacklisted but request succeeded",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details
                )
            } catch {
                // We expect this to fail with 401
                if let apiError = error as? APIError,
                   apiError.statusCode == 401 {
                    return TestResult(
                        testName: "Token Blacklist",
                        category: TestCategory.tokenManagement.rawValue,
                        success: true,
                        message: "Correctly rejected blacklisted token",
                        executionTime: Date().timeIntervalSince(startTime),
                        details: details
                    )
                }
                
                throw error
            }
        } catch {
            return TestResult(
                testName: "Token Blacklist",
                category: TestCategory.tokenManagement.rawValue,
                success: false,
                message: "Token blacklist test failed",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "BLACKLIST_TEST_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Complete Token Lifecycle Test
    
    func testCompleteTokenLifecycle(
        initialAccessToken: String,
        initialRefreshToken: String
    ) async throws -> TestResult {
        let startTime = Date()
        var allStepsPassed = true
        var messages: [String] = []
        
        // Step 1: Validate initial token
        let validationResult = try await testTokenValidation(accessToken: initialAccessToken)
        allStepsPassed = allStepsPassed && validationResult.success
        messages.append("Initial validation: \(validationResult.success ? "✓" : "✗")")
        
        // Step 2: Refresh token
        let refreshResult = try await testTokenRefresh(refreshToken: initialRefreshToken)
        allStepsPassed = allStepsPassed && refreshResult.success
        messages.append("Token refresh: \(refreshResult.success ? "✓" : "✗")")
        
        if let newAccessToken = refreshResult.details?.accessToken {
            // Step 3: Validate new token
            let newValidationResult = try await testTokenValidation(accessToken: newAccessToken)
            allStepsPassed = allStepsPassed && newValidationResult.success
            messages.append("New token validation: \(newValidationResult.success ? "✓" : "✗")")
            
            // Step 4: Test blacklisting
            let blacklistResult = try await testTokenBlacklist(token: newAccessToken)
            allStepsPassed = allStepsPassed && blacklistResult.success
            messages.append("Token blacklist: \(blacklistResult.success ? "✓" : "✗")")
        }
        
        return TestResult(
            testName: "Complete Token Lifecycle",
            category: TestCategory.tokenManagement.rawValue,
            success: allStepsPassed,
            message: "Lifecycle test: " + messages.joined(separator: ", "),
            executionTime: Date().timeIntervalSince(startTime),
            details: nil
        )
    }
}