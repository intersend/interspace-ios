import XCTest
import Combine
@testable import Interspace

@MainActor
class AuthenticationManagerTests: XCTestCase {
    
    var sut: AuthenticationManager!
    var mockAPIService: MockAPIService!
    var mockKeychainManager: MockKeychainManager!
    var mockAuthAPI: AuthAPI!
    var mockUserAPI: UserAPI!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        await super.setUp()
        
        // Setup mocks
        mockAPIService = MockAPIService()
        mockKeychainManager = MockKeychainManager()
        cancellables = Set<AnyCancellable>()
        
        // Replace shared instances with mocks
        APIService.shared = mockAPIService
        KeychainManager.shared = mockKeychainManager
        
        // Initialize services
        mockAuthAPI = AuthAPI.shared
        mockUserAPI = UserAPI.shared
        
        // Create SUT
        sut = AuthenticationManager.shared
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        mockAPIService.reset()
        mockKeychainManager.reset()
        sut = nil
        await super.tearDown()
    }
    
    // MARK: - Authentication Tests
    
    func testAuthenticateWithWalletSuccess() async throws {
        // Given
        let config = TestDataFactory.createWalletConnectionConfig()
        let authResponse = TestDataFactory.createAuthResponse()
        let testUser = TestDataFactory.createTestUser()
        
        mockAPIService.mockResponses["/auth/authenticate"] = authResponse
        mockAPIService.mockResponses["/users/me"] = testUser
        
        // When
        try await sut.authenticate(with: config)
        
        // Then
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertNotNil(sut.currentUser)
        XCTAssertEqual(sut.currentUser?.id, testUser.id)
        XCTAssertNil(sut.error)
        
        // Verify tokens were saved
        XCTAssertEqual(mockKeychainManager.getAccessToken(), authResponse.data.accessToken)
        XCTAssertEqual(mockKeychainManager.getRefreshToken(), authResponse.data.refreshToken)
        
        // Verify API calls
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/auth/authenticate", method: .POST))
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/users/me", method: .GET))
    }
    
    func testAuthenticateWithEmailSuccess() async throws {
        // Given
        let config = WalletConnectionConfig(
            strategy: .email,
            walletType: nil,
            email: "test@example.com",
            verificationCode: "123456",
            walletAddress: nil,
            signature: nil,
            socialProvider: nil,
            socialProfile: nil
        )
        let authResponse = TestDataFactory.createAuthResponse()
        let testUser = TestDataFactory.createTestUser(email: "test@example.com")
        
        mockAPIService.mockResponses["/auth/authenticate"] = authResponse
        mockAPIService.mockResponses["/users/me"] = testUser
        
        // When
        try await sut.authenticate(with: config)
        
        // Then
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertNotNil(sut.currentUser)
        XCTAssertEqual(sut.currentUser?.email, "test@example.com")
    }
    
    func testAuthenticateAsGuestSuccess() async throws {
        // Given
        let config = WalletConnectionConfig(
            strategy: .guest,
            walletType: nil,
            email: nil,
            verificationCode: nil,
            walletAddress: nil,
            signature: nil,
            socialProvider: nil,
            socialProfile: nil
        )
        let authResponse = TestDataFactory.createAuthResponse()
        
        mockAPIService.mockResponses["/auth/authenticate"] = authResponse
        
        // When
        try await sut.authenticate(with: config)
        
        // Then
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertNotNil(sut.currentUser)
        XCTAssertTrue(sut.currentUser?.isGuest ?? false)
        XCTAssertEqual(sut.currentUser?.authStrategies, ["guest"])
        
        // Verify no user fetch for guest
        XCTAssertFalse(mockAPIService.verifyRequest(endpoint: "/users/me", method: .GET))
    }
    
    func testAuthenticateFailureHandling() async throws {
        // Given
        let config = TestDataFactory.createWalletConnectionConfig()
        mockAPIService.mockErrors["/auth/authenticate"] = APIError.unauthorized
        
        // When/Then
        await XCTAssertAsyncThrowsError(
            try await sut.authenticate(with: config)
        ) { error in
            XCTAssertTrue(error is AuthenticationError)
            if let authError = error as? AuthenticationError {
                switch authError {
                case .invalidCredentials:
                    break // Expected
                default:
                    XCTFail("Unexpected error type: \(authError)")
                }
            }
        }
        
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.currentUser)
        XCTAssertNotNil(sut.error)
    }
    
    // MARK: - Token Refresh Tests
    
    func testRefreshTokenSuccess() async throws {
        // Given
        mockKeychainManager.setTokens(access: "old-token", refresh: "refresh-token", expired: true)
        
        let refreshResponse = RefreshTokenResponse(
            accessToken: "new-access-token",
            expiresIn: 3600
        )
        let testUser = TestDataFactory.createTestUser()
        
        mockAPIService.mockResponses["/auth/refresh"] = refreshResponse
        mockAPIService.mockResponses["/users/me"] = testUser
        
        // When
        await sut.refreshTokenIfNeeded()
        
        // Then
        XCTAssertEqual(mockKeychainManager.getAccessToken(), "new-access-token")
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/auth/refresh", method: .POST))
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertNotNil(sut.currentUser)
    }
    
    func testRefreshTokenFailureLogsOut() async throws {
        // Given
        mockKeychainManager.setTokens(access: "old-token", refresh: "refresh-token", expired: true)
        mockAPIService.mockErrors["/auth/refresh"] = APIError.unauthorized
        
        // When
        await sut.refreshTokenIfNeeded()
        
        // Then
        XCTAssertNil(mockKeychainManager.getAccessToken())
        XCTAssertNil(mockKeychainManager.getRefreshToken())
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.currentUser)
    }
    
    // MARK: - Email Code Tests
    
    func testSendEmailCodeSuccess() async throws {
        // Given
        let email = "test@example.com"
        mockAPIService.mockResponses["/auth/send-code"] = EmailCodeResponse(success: true, message: "Code sent")
        
        // When
        try await sut.sendEmailCode(email)
        
        // Then
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/auth/send-code", method: .POST))
        
        if let requestBody = mockAPIService.getLastRequestBody(for: "/auth/send-code", as: [String: String].self) {
            XCTAssertEqual(requestBody["email"], email)
        } else {
            XCTFail("Request body not found")
        }
    }
    
    // MARK: - Logout Tests
    
    func testLogoutClearsEverything() async throws {
        // Given
        mockKeychainManager.setTokens(access: "token", refresh: "refresh-token")
        sut.isAuthenticated = true
        sut.currentUser = TestDataFactory.createTestUser()
        
        mockAPIService.mockResponses["/auth/logout"] = EmptyResponse()
        
        // When
        await sut.logout()
        
        // Then
        XCTAssertNil(mockKeychainManager.getAccessToken())
        XCTAssertNil(mockKeychainManager.getRefreshToken())
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.currentUser)
        XCTAssertNil(sut.error)
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/auth/logout", method: .POST))
    }
    
    // MARK: - Session Check Tests
    
    func testCheckAuthenticationStatusWithValidToken() async throws {
        // Given
        mockKeychainManager.setTokens(access: "valid-token", refresh: "refresh-token", expired: false)
        let testUser = TestDataFactory.createTestUser()
        mockAPIService.mockResponses["/users/me"] = testUser
        
        // When
        sut.checkAuthenticationStatus()
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertTrue(sut.isAuthenticated)
        XCTAssertNotNil(sut.currentUser)
        XCTAssertEqual(sut.currentUser?.id, testUser.id)
    }
    
    func testCheckAuthenticationStatusWithExpiredToken() async throws {
        // Given
        mockKeychainManager.setTokens(access: "expired-token", refresh: "refresh-token", expired: true)
        
        let refreshResponse = RefreshTokenResponse(
            accessToken: "new-token",
            expiresIn: 3600
        )
        mockAPIService.mockResponses["/auth/refresh"] = refreshResponse
        
        // When
        sut.checkAuthenticationStatus()
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/auth/refresh", method: .POST))
    }
    
    func testCheckAuthenticationStatusWithNoToken() {
        // Given
        mockKeychainManager.clearTokens()
        
        // When
        sut.checkAuthenticationStatus()
        
        // Then
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.currentUser)
    }
}