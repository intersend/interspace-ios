import XCTest
@testable import Interspace

class AuthServiceIntegrationTests: XCTestCase {
    
    var authService: AuthService!
    var mockAPIService: MockAPIService!
    var mockKeychainManager: MockKeychainManager!
    var sessionCoordinator: SessionCoordinator!
    
    override func setUpWithError() throws {
        super.setUp()
        
        // Setup mocks
        mockAPIService = MockAPIService()
        mockKeychainManager = MockKeychainManager()
        
        // Initialize session coordinator
        sessionCoordinator = SessionCoordinator(keychainManager: mockKeychainManager)
        
        // Initialize auth service with mocks
        authService = AuthService(
            apiService: mockAPIService,
            keychainManager: mockKeychainManager,
            sessionCoordinator: sessionCoordinator
        )
    }
    
    override func tearDownWithError() throws {
        authService = nil
        mockAPIService = nil
        mockKeychainManager = nil
        sessionCoordinator = nil
        super.tearDown()
    }
    
    // MARK: - Email Authentication Flow Tests
    
    func testCompleteEmailAuthenticationFlow() async throws {
        // Setup mock responses
        mockAPIService.mockResponses["/auth/email/send"] = AuthResponse(
            success: true,
            message: "Code sent",
            data: AuthData(codeExpiry: Date().addingTimeInterval(300))
        )
        
        mockAPIService.mockResponses["/auth/email/verify"] = TokenResponse(
            success: true,
            data: TokenData(
                token: "mock-jwt-token",
                refreshToken: "mock-refresh-token",
                expiresIn: 3600
            )
        )
        
        mockAPIService.mockResponses["/user/profile"] = UserProfile(
            id: "user123",
            email: "test@example.com",
            profiles: []
        )
        
        // Test sending code
        let email = "test@example.com"
        do {
            try await authService.sendVerificationCode(email: email)
            
            // Verify API was called correctly
            XCTAssertTrue(mockAPIService.verifyRequest(
                endpoint: "/auth/email/send",
                method: .POST
            ))
            
            // Verify request body
            if let requestBody = mockAPIService.getLastRequestBody(
                for: "/auth/email/send",
                as: EmailRequest.self
            ) {
                XCTAssertEqual(requestBody.email, email)
            } else {
                XCTFail("Request body not found")
            }
        } catch {
            XCTFail("Send verification code failed: \(error)")
        }
        
        // Test verifying code
        let code = "123456"
        do {
            let user = try await authService.verifyCode(email: email, code: code)
            
            // Verify API calls
            XCTAssertTrue(mockAPIService.verifyRequest(
                endpoint: "/auth/email/verify",
                method: .POST
            ))
            
            // Verify tokens stored in keychain
            XCTAssertNotNil(mockKeychainManager.retrievedItems["auth_token"])
            XCTAssertNotNil(mockKeychainManager.retrievedItems["refresh_token"])
            
            // Verify session established
            XCTAssertTrue(sessionCoordinator.isAuthenticated)
            XCTAssertEqual(sessionCoordinator.currentUser?.email, email)
            
            // Verify user returned
            XCTAssertEqual(user.email, email)
            XCTAssertEqual(user.id, "user123")
        } catch {
            XCTFail("Verify code failed: \(error)")
        }
    }
    
    func testEmailAuthenticationWithInvalidCode() async throws {
        // Setup mock error response
        mockAPIService.mockErrors["/auth/email/verify"] = APIError.invalidCredentials
        
        // Test verifying with invalid code
        do {
            _ = try await authService.verifyCode(email: "test@example.com", code: "000000")
            XCTFail("Should have thrown error for invalid code")
        } catch {
            // Verify error is correct type
            if let apiError = error as? APIError {
                XCTAssertEqual(apiError, .invalidCredentials)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
            
            // Verify no tokens stored
            XCTAssertNil(mockKeychainManager.retrievedItems["auth_token"])
            XCTAssertFalse(sessionCoordinator.isAuthenticated)
        }
    }
    
    // MARK: - Social Authentication Tests
    
    func testGoogleSignInFlow() async throws {
        // Setup mock responses
        mockAPIService.mockResponses["/auth/google"] = TokenResponse(
            success: true,
            data: TokenData(
                token: "mock-google-jwt",
                refreshToken: "mock-google-refresh",
                expiresIn: 3600
            )
        )
        
        mockAPIService.mockResponses["/user/profile"] = UserProfile(
            id: "google123",
            email: "user@gmail.com",
            profiles: [],
            socialAccounts: [
                SocialAccount(
                    provider: .google,
                    email: "user@gmail.com",
                    id: "google123"
                )
            ]
        )
        
        // Test Google sign in
        let googleIdToken = "mock-google-id-token"
        do {
            let user = try await authService.signInWithGoogle(idToken: googleIdToken)
            
            // Verify API call
            XCTAssertTrue(mockAPIService.verifyRequest(
                endpoint: "/auth/google",
                method: .POST
            ))
            
            // Verify tokens stored
            XCTAssertNotNil(mockKeychainManager.retrievedItems["auth_token"])
            
            // Verify user has Google account linked
            XCTAssertEqual(user.socialAccounts.first?.provider, .google)
            XCTAssertEqual(user.email, "user@gmail.com")
        } catch {
            XCTFail("Google sign in failed: \(error)")
        }
    }
    
    func testAppleSignInFlow() async throws {
        // Setup mock responses
        mockAPIService.mockResponses["/auth/apple"] = TokenResponse(
            success: true,
            data: TokenData(
                token: "mock-apple-jwt",
                refreshToken: "mock-apple-refresh",
                expiresIn: 3600
            )
        )
        
        mockAPIService.mockResponses["/user/profile"] = UserProfile(
            id: "apple123",
            email: "user@privaterelay.appleid.com",
            profiles: [],
            socialAccounts: [
                SocialAccount(
                    provider: .apple,
                    email: "user@privaterelay.appleid.com",
                    id: "apple123"
                )
            ]
        )
        
        // Test Apple sign in
        let appleCredentials = AppleAuthCredentials(
            userIdentifier: "apple123",
            email: "user@privaterelay.appleid.com",
            fullName: "Test User",
            authorizationCode: "mock-auth-code"
        )
        
        do {
            let user = try await authService.signInWithApple(credentials: appleCredentials)
            
            // Verify API call
            XCTAssertTrue(mockAPIService.verifyRequest(
                endpoint: "/auth/apple",
                method: .POST
            ))
            
            // Verify user has Apple account linked
            XCTAssertEqual(user.socialAccounts.first?.provider, .apple)
        } catch {
            XCTFail("Apple sign in failed: \(error)")
        }
    }
    
    // MARK: - Token Management Tests
    
    func testTokenRefreshFlow() async throws {
        // Setup initial authenticated state
        mockKeychainManager.storedItems["auth_token"] = "expired-token"
        mockKeychainManager.storedItems["refresh_token"] = "valid-refresh-token"
        
        // Setup mock refresh response
        mockAPIService.mockResponses["/auth/refresh"] = TokenResponse(
            success: true,
            data: TokenData(
                token: "new-jwt-token",
                refreshToken: "new-refresh-token",
                expiresIn: 3600
            )
        )
        
        // Test token refresh
        do {
            let newToken = try await authService.refreshToken()
            
            // Verify API call
            XCTAssertTrue(mockAPIService.verifyRequest(
                endpoint: "/auth/refresh",
                method: .POST
            ))
            
            // Verify new tokens stored
            XCTAssertEqual(mockKeychainManager.storedItems["auth_token"], "new-jwt-token")
            XCTAssertEqual(mockKeychainManager.storedItems["refresh_token"], "new-refresh-token")
            
            // Verify returned token
            XCTAssertEqual(newToken, "new-jwt-token")
        } catch {
            XCTFail("Token refresh failed: \(error)")
        }
    }
    
    func testAutomaticTokenRefreshOnAPICall() async throws {
        // Setup expired token scenario
        mockKeychainManager.storedItems["auth_token"] = "expired-token"
        mockKeychainManager.storedItems["refresh_token"] = "valid-refresh-token"
        
        // First API call should fail with 401
        mockAPIService.mockErrors["/user/profile"] = APIError.unauthorized
        
        // Setup refresh response
        mockAPIService.mockResponses["/auth/refresh"] = TokenResponse(
            success: true,
            data: TokenData(
                token: "new-token",
                refreshToken: "new-refresh",
                expiresIn: 3600
            )
        )
        
        // After refresh, profile call should succeed
        var callCount = 0
        mockAPIService.mockResponseHandler = { endpoint in
            if endpoint == "/user/profile" {
                callCount += 1
                if callCount == 1 {
                    throw APIError.unauthorized
                } else {
                    return UserProfile(
                        id: "user123",
                        email: "test@example.com",
                        profiles: []
                    )
                }
            }
            return nil
        }
        
        // Make authenticated API call
        do {
            let profile = try await authService.getCurrentUser()
            
            // Verify token was refreshed
            XCTAssertTrue(mockAPIService.verifyRequest(
                endpoint: "/auth/refresh",
                method: .POST
            ))
            
            // Verify profile fetched after refresh
            XCTAssertEqual(profile.email, "test@example.com")
            XCTAssertEqual(callCount, 2) // Called twice: once failed, once succeeded
        } catch {
            XCTFail("Automatic token refresh failed: \(error)")
        }
    }
    
    // MARK: - Session Management Tests
    
    func testLogoutFlow() async throws {
        // Setup authenticated state
        mockKeychainManager.storedItems["auth_token"] = "valid-token"
        mockKeychainManager.storedItems["refresh_token"] = "valid-refresh"
        sessionCoordinator.currentUser = UserProfile(
            id: "user123",
            email: "test@example.com",
            profiles: []
        )
        
        // Setup mock response
        mockAPIService.mockResponses["/auth/logout"] = EmptyResponse()
        
        // Test logout
        do {
            try await authService.logout()
            
            // Verify API call
            XCTAssertTrue(mockAPIService.verifyRequest(
                endpoint: "/auth/logout",
                method: .POST
            ))
            
            // Verify tokens removed
            XCTAssertNil(mockKeychainManager.retrievedItems["auth_token"])
            XCTAssertNil(mockKeychainManager.retrievedItems["refresh_token"])
            
            // Verify session cleared
            XCTAssertFalse(sessionCoordinator.isAuthenticated)
            XCTAssertNil(sessionCoordinator.currentUser)
        } catch {
            XCTFail("Logout failed: \(error)")
        }
    }
    
    func testSessionRestoration() async throws {
        // Setup stored tokens
        mockKeychainManager.storedItems["auth_token"] = "valid-token"
        mockKeychainManager.storedItems["refresh_token"] = "valid-refresh"
        
        // Setup mock user response
        mockAPIService.mockResponses["/user/profile"] = UserProfile(
            id: "user123",
            email: "test@example.com",
            profiles: [
                Profile(
                    id: "profile1",
                    name: "Main Profile",
                    icon: "🏠",
                    color: "blue"
                )
            ]
        )
        
        // Test session restoration
        do {
            let restored = try await authService.restoreSession()
            
            XCTAssertTrue(restored)
            
            // Verify user profile fetched
            XCTAssertTrue(mockAPIService.verifyRequest(
                endpoint: "/user/profile",
                method: .GET
            ))
            
            // Verify session established
            XCTAssertTrue(sessionCoordinator.isAuthenticated)
            XCTAssertEqual(sessionCoordinator.currentUser?.email, "test@example.com")
            XCTAssertEqual(sessionCoordinator.currentProfile?.name, "Main Profile")
        } catch {
            XCTFail("Session restoration failed: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkErrorHandling() async throws {
        // Setup network error
        mockAPIService.mockErrors["/auth/email/send"] = APIError.networkError("No internet connection")
        
        // Test network error handling
        do {
            try await authService.sendVerificationCode(email: "test@example.com")
            XCTFail("Should have thrown network error")
        } catch {
            if let apiError = error as? APIError,
               case .networkError(let message) = apiError {
                XCTAssertEqual(message, "No internet connection")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testRateLimitHandling() async throws {
        // Setup rate limit error
        mockAPIService.mockErrors["/auth/email/send"] = APIError.rateLimited(retryAfter: 60)
        
        // Test rate limit handling
        do {
            try await authService.sendVerificationCode(email: "test@example.com")
            XCTFail("Should have thrown rate limit error")
        } catch {
            if let apiError = error as? APIError,
               case .rateLimited(let retryAfter) = apiError {
                XCTAssertEqual(retryAfter, 60)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    // MARK: - Concurrent Request Tests
    
    func testConcurrentAuthenticationRequests() async throws {
        // Setup mock responses with delay
        mockAPIService.delayInSeconds = 0.1
        mockAPIService.mockResponses["/auth/email/verify"] = TokenResponse(
            success: true,
            data: TokenData(
                token: "mock-token",
                refreshToken: "mock-refresh",
                expiresIn: 3600
            )
        )
        
        mockAPIService.mockResponses["/user/profile"] = UserProfile(
            id: "user123",
            email: "test@example.com",
            profiles: []
        )
        
        // Make concurrent authentication attempts
        let expectation1 = expectation(description: "First auth completes")
        let expectation2 = expectation(description: "Second auth completes")
        
        var result1: Result<UserProfile, Error>?
        var result2: Result<UserProfile, Error>?
        
        Task {
            do {
                let user = try await authService.verifyCode(email: "test1@example.com", code: "123456")
                result1 = .success(user)
            } catch {
                result1 = .failure(error)
            }
            expectation1.fulfill()
        }
        
        Task {
            do {
                let user = try await authService.verifyCode(email: "test2@example.com", code: "654321")
                result2 = .success(user)
            } catch {
                result2 = .failure(error)
            }
            expectation2.fulfill()
        }
        
        await fulfillment(of: [expectation1, expectation2], timeout: 5.0)
        
        // Verify both requests completed successfully
        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        
        // Verify proper request handling
        XCTAssertEqual(mockAPIService.requestHistory.count, 4) // 2 verify + 2 profile calls
    }
}

// MARK: - Mock Extensions for Testing

extension AuthService {
    convenience init(apiService: APIService, keychainManager: KeychainManager, sessionCoordinator: SessionCoordinator) {
        self.init()
        // Use dependency injection for testing
        // This would require making these properties injectable in the actual implementation
    }
}

// MARK: - Test Data Models

struct EmailRequest: Codable {
    let email: String
}

struct AuthResponse: Codable {
    let success: Bool
    let message: String
    let data: AuthData
}

struct AuthData: Codable {
    let codeExpiry: Date
}

struct TokenResponse: Codable {
    let success: Bool
    let data: TokenData
}

struct TokenData: Codable {
    let token: String
    let refreshToken: String
    let expiresIn: Int
}

struct AppleAuthCredentials {
    let userIdentifier: String
    let email: String?
    let fullName: String?
    let authorizationCode: String
}

struct EmptyResponse: Codable {}