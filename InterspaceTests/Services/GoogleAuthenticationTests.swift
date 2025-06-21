import XCTest
@testable import Interspace

@MainActor
class GoogleAuthenticationTests: XCTestCase {
    
    var authManager: AuthenticationManager!
    var mockAPIService: MockAPIService!
    var mockKeychainManager: MockKeychainManager!
    
    override func setUp() async throws {
        await super.setUp()
        
        // Setup mocks
        mockAPIService = MockAPIService()
        mockKeychainManager = MockKeychainManager()
        
        // Replace shared instances
        APIService.shared = mockAPIService
        KeychainManager.shared = mockKeychainManager
        
        // Initialize auth manager
        authManager = AuthenticationManager.shared
    }
    
    override func tearDown() async throws {
        mockAPIService.reset()
        mockKeychainManager.reset()
        await super.tearDown()
    }
    
    // MARK: - Google Authentication Tests
    
    func testGoogleAuthenticationWithValidIDToken() async throws {
        // Given: Valid Google sign-in response with ID token
        let authResponse = TestDataFactory.createAuthResponse()
        let testUser = TestDataFactory.createTestUser(email: "testuser@gmail.com")
        
        mockAPIService.mockResponses["/auth/authenticate"] = authResponse
        mockAPIService.mockResponses["/users/me"] = testUser
        
        // When: Authenticating with Google (in development mode for testing)
        EnvironmentConfiguration.shared.isDevelopmentModeEnabled = true
        
        do {
            try await authManager.authenticateWithGoogle()
            
            // Then: User should be authenticated
            XCTAssertTrue(authManager.isAuthenticated)
            XCTAssertNotNil(authManager.currentUser)
            XCTAssertEqual(authManager.currentUser?.email, "testuser@gmail.com")
            
            // Verify tokens were saved
            XCTAssertNotNil(mockKeychainManager.getAccessToken())
            XCTAssertNotNil(mockKeychainManager.getRefreshToken())
            
            // Verify correct API call was made
            XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/auth/authenticate", method: .POST))
            
            // Verify auth request contains Google strategy
            if let lastRequest = mockAPIService.lastRequest,
               let body = lastRequest.httpBody,
               let authRequest = try? JSONDecoder().decode(AuthenticationRequest.self, from: body) {
                XCTAssertEqual(authRequest.authStrategy, "google")
                XCTAssertNotNil(authRequest.authToken)
                XCTAssertNotNil(authRequest.socialData)
                XCTAssertEqual(authRequest.socialData?.provider, "google")
            } else {
                XCTFail("Failed to decode authentication request")
            }
            
        } catch {
            XCTFail("Google authentication failed with error: \(error)")
        }
        
        // Cleanup
        EnvironmentConfiguration.shared.isDevelopmentModeEnabled = false
    }
    
    func testGoogleAuthenticationErrorHandling() async throws {
        // Given: API returns error
        mockAPIService.shouldFailNextRequest = true
        mockAPIService.errorToReturn = APIError.unauthorized
        
        // When: Attempting Google authentication
        EnvironmentConfiguration.shared.isDevelopmentModeEnabled = true
        
        do {
            try await authManager.authenticateWithGoogle()
            XCTFail("Expected authentication to fail")
        } catch {
            // Then: Error should be handled properly
            XCTAssertFalse(authManager.isAuthenticated)
            XCTAssertNil(authManager.currentUser)
            XCTAssertNotNil(error as? AuthenticationError)
        }
        
        // Cleanup
        EnvironmentConfiguration.shared.isDevelopmentModeEnabled = false
    }
    
    func testGoogleSignInServiceConfiguration() {
        // Given: GoogleSignInService
        let googleService = GoogleSignInService.shared
        
        // When: Configuring the service
        googleService.configure()
        
        // Then: Service should be configured
        // Note: We can't fully test the configuration without mocking GIDSignIn
        // but we can verify the method doesn't crash
        XCTAssertNotNil(googleService)
    }
    
    func testGoogleAuthenticationSocialDataMapping() async throws {
        // Given: Google authentication with social data
        let authResponse = TestDataFactory.createAuthResponse()
        let testUser = TestDataFactory.createTestUser(email: "testuser@gmail.com")
        
        mockAPIService.mockResponses["/auth/authenticate"] = authResponse
        mockAPIService.mockResponses["/users/me"] = testUser
        
        EnvironmentConfiguration.shared.isDevelopmentModeEnabled = true
        
        // When: Authenticating with Google
        try await authManager.authenticateWithGoogle()
        
        // Then: Social data should be properly mapped
        if let lastRequest = mockAPIService.lastRequest,
           let body = lastRequest.httpBody,
           let authRequest = try? JSONDecoder().decode(AuthenticationRequest.self, from: body),
           let socialData = authRequest.socialData {
            
            XCTAssertEqual(socialData.provider, "google")
            XCTAssertEqual(socialData.email, "dev.user@example.com") // Development mode email
            XCTAssertEqual(socialData.displayName, "Development User")
            XCTAssertNotNil(socialData.providerId)
            
        } else {
            XCTFail("Failed to verify social data mapping")
        }
        
        // Cleanup
        EnvironmentConfiguration.shared.isDevelopmentModeEnabled = false
    }
}

// MARK: - Test Helpers

extension TestDataFactory {
    static func createGoogleSignInResult(
        email: String = "testuser@gmail.com",
        name: String = "Test User",
        idToken: String? = "test_id_token_123"
    ) -> GoogleSignInResult {
        return GoogleSignInResult(
            email: email,
            name: name,
            imageURL: "https://example.com/avatar.jpg",
            idToken: idToken,
            userId: "google_user_123"
        )
    }
}