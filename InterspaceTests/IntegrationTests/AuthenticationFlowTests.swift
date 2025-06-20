import XCTest
import Combine
@testable import Interspace

@MainActor
class AuthenticationFlowTests: XCTestCase {
    
    var mockAPIService: MockAPIService!
    var mockKeychainManager: MockKeychainManager!
    var authManager: AuthenticationManager!
    var sessionCoordinator: SessionCoordinator!
    var authViewModel: AuthViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        await super.setUp()
        
        // Setup mocks
        mockAPIService = MockAPIService()
        mockKeychainManager = MockKeychainManager()
        cancellables = Set<AnyCancellable>()
        
        // Replace shared instances
        APIService.shared = mockAPIService
        KeychainManager.shared = mockKeychainManager
        
        // Initialize services
        authManager = AuthenticationManager.shared
        sessionCoordinator = SessionCoordinator.shared
        authViewModel = AuthViewModel()
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        mockAPIService.reset()
        mockKeychainManager.reset()
        await super.tearDown()
    }
    
    // MARK: - End-to-End Authentication Flow Tests
    
    func testCompleteEmailAuthenticationFlow() async throws {
        // Step 1: User selects email authentication
        authViewModel.selectAuthStrategy(.email)
        XCTAssertEqual(authViewModel.selectedAuthStrategy, .email)
        
        // Step 2: User enters email and requests code
        authViewModel.email = "test@example.com"
        mockAPIService.mockResponses["/auth/send-code"] = EmailCodeResponse(success: true, message: "Code sent")
        
        authViewModel.sendEmailCode()
        try await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertTrue(authViewModel.isEmailCodeSent)
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/auth/send-code", method: .POST))
        
        // Step 3: User enters verification code
        authViewModel.verificationCode = "123456"
        
        let authResponse = TestDataFactory.createAuthResponse()
        let testUser = TestDataFactory.createTestUser(email: "test@example.com")
        let testProfile = TestDataFactory.createTestProfile()
        
        mockAPIService.mockResponses["/auth/authenticate"] = authResponse
        mockAPIService.mockResponses["/users/me"] = testUser
        mockAPIService.mockResponses["/profiles"] = [testProfile]
        
        // Step 4: Complete authentication
        authViewModel.verifyEmailCode()
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Verify authentication success
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertNotNil(authManager.currentUser)
        XCTAssertEqual(authManager.currentUser?.email, "test@example.com")
        
        // Verify session state
        XCTAssertEqual(sessionCoordinator.sessionState, .authenticated)
        XCTAssertNotNil(sessionCoordinator.currentUser)
        XCTAssertNotNil(sessionCoordinator.activeProfile)
        
        // Verify tokens were saved
        XCTAssertNotNil(mockKeychainManager.getAccessToken())
        XCTAssertNotNil(mockKeychainManager.getRefreshToken())
    }
    
    func testCompleteWalletAuthenticationFlow() async throws {
        // Step 1: User selects wallet authentication
        authViewModel.selectAuthStrategy(.wallet)
        XCTAssertTrue(authViewModel.showWalletTray)
        
        // Step 2: User selects MetaMask
        authViewModel.selectWallet(.metamask)
        XCTAssertEqual(authViewModel.selectedWalletType, .metamask)
        XCTAssertFalse(authViewModel.showWalletTray)
        
        // Step 3: Mock wallet connection and authentication
        let authResponse = TestDataFactory.createAuthResponse()
        let testUser = TestDataFactory.createTestUser(walletAddress: "0x1234567890")
        let testProfile = TestDataFactory.createTestProfile()
        
        mockAPIService.mockResponses["/auth/authenticate"] = authResponse
        mockAPIService.mockResponses["/users/me"] = testUser
        mockAPIService.mockResponses["/profiles"] = [testProfile]
        
        // Note: In real scenario, wallet service would handle the connection
        // For testing, we'll directly trigger the authentication
        let config = TestDataFactory.createWalletConnectionConfig(
            walletAddress: "0x1234567890",
            signature: "0xsignature"
        )
        
        try await authManager.authenticate(with: config)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify authentication success
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertEqual(authManager.currentUser?.walletAddress, "0x1234567890")
        
        // Verify session state
        XCTAssertEqual(sessionCoordinator.sessionState, .authenticated)
        XCTAssertNotNil(sessionCoordinator.activeProfile)
    }
    
    func testGuestAuthenticationFlow() async throws {
        // Step 1: User selects guest authentication
        authViewModel.selectAuthStrategy(.guest)
        
        let authResponse = TestDataFactory.createAuthResponse()
        mockAPIService.mockResponses["/auth/authenticate"] = authResponse
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify guest authentication
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertNotNil(authManager.currentUser)
        XCTAssertTrue(authManager.currentUser?.isGuest ?? false)
        
        // Verify session state for guest
        XCTAssertEqual(sessionCoordinator.sessionState, .authenticated)
        XCTAssertNil(sessionCoordinator.activeProfile) // Guest users don't have profiles
    }
    
    // MARK: - Token Refresh Flow Tests
    
    func testTokenRefreshDuringAPICall() async throws {
        // Setup: User is authenticated with expired token
        mockKeychainManager.setTokens(
            access: "expired-token",
            refresh: "valid-refresh-token",
            expired: true
        )
        
        let refreshResponse = RefreshTokenResponse(
            accessToken: "new-access-token",
            expiresIn: 3600
        )
        let testUser = TestDataFactory.createTestUser()
        
        mockAPIService.mockResponses["/auth/refresh"] = refreshResponse
        mockAPIService.mockResponses["/users/me"] = testUser
        
        // Trigger authentication check
        authManager.checkAuthenticationStatus()
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify token was refreshed
        XCTAssertEqual(mockKeychainManager.getAccessToken(), "new-access-token")
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertNotNil(authManager.currentUser)
        
        // Verify API calls
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/auth/refresh", method: .POST))
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/users/me", method: .GET))
    }
    
    // MARK: - Profile Creation Flow Tests
    
    func testNewUserProfileCreationFlow() async throws {
        // Setup: User authenticated but no profiles
        let testUser = TestDataFactory.createTestUser(profilesCount: 0)
        authManager.currentUser = testUser
        authManager.isAuthenticated = true
        
        mockAPIService.mockResponses["/users/me"] = testUser
        mockAPIService.mockResponses["/profiles"] = [SmartProfile]()
        
        // Load session - should transition to needsProfile
        await sessionCoordinator.loadUserSession()
        
        XCTAssertEqual(sessionCoordinator.sessionState, .needsProfile)
        
        // Create first profile
        let newProfile = TestDataFactory.createTestProfile(name: "My Gaming Profile")
        mockAPIService.mockResponses["/profiles"] = newProfile
        mockAPIService.mockResponses["/profiles/\(newProfile.id)/activate"] = ["success": true]
        
        await sessionCoordinator.createInitialProfile(name: "My Gaming Profile")
        
        // Verify profile creation and activation
        XCTAssertEqual(sessionCoordinator.sessionState, .authenticated)
        XCTAssertNotNil(sessionCoordinator.activeProfile)
        XCTAssertEqual(sessionCoordinator.activeProfile?.name, "My Gaming Profile")
        
        // Verify API calls
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/profiles", method: .POST))
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/profiles/\(newProfile.id)/activate", method: .POST))
    }
    
    // MARK: - Error Recovery Flow Tests
    
    func testAuthenticationErrorRecovery() async throws {
        // Step 1: Initial authentication fails
        authViewModel.email = "test@example.com"
        authViewModel.verificationCode = "123456"
        
        mockAPIService.mockErrors["/auth/authenticate"] = APIError.unauthorized
        
        authViewModel.verifyEmailCode()
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify error state
        XCTAssertNotNil(authViewModel.error)
        XCTAssertTrue(authViewModel.showError)
        XCTAssertFalse(authManager.isAuthenticated)
        
        // Step 2: User dismisses error and retries
        authViewModel.dismissError()
        XCTAssertNil(authViewModel.error)
        
        // Mock successful response for retry
        mockAPIService.mockErrors.removeAll()
        let authResponse = TestDataFactory.createAuthResponse()
        let testUser = TestDataFactory.createTestUser()
        
        mockAPIService.mockResponses["/auth/authenticate"] = authResponse
        mockAPIService.mockResponses["/users/me"] = testUser
        mockAPIService.mockResponses["/profiles"] = [TestDataFactory.createTestProfile()]
        
        // Retry authentication
        authViewModel.verifyEmailCode()
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Verify successful recovery
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertNil(authViewModel.error)
        XCTAssertEqual(sessionCoordinator.sessionState, .authenticated)
    }
    
    // MARK: - Session Persistence Tests
    
    func testSessionPersistenceAcrossAppLaunches() async throws {
        // Simulate first app launch and authentication
        let authResponse = TestDataFactory.createAuthResponse()
        let testUser = TestDataFactory.createTestUser()
        let testProfile = TestDataFactory.createTestProfile()
        
        mockAPIService.mockResponses["/auth/authenticate"] = authResponse
        mockAPIService.mockResponses["/users/me"] = testUser
        mockAPIService.mockResponses["/profiles"] = [testProfile]
        
        // Authenticate
        let config = TestDataFactory.createWalletConnectionConfig()
        try await authManager.authenticate(with: config)
        
        // Verify tokens are saved
        XCTAssertNotNil(mockKeychainManager.getAccessToken())
        XCTAssertNotNil(mockKeychainManager.getRefreshToken())
        
        // Simulate app restart by creating new instances
        let newAuthManager = AuthenticationManager.shared
        let newSessionCoordinator = SessionCoordinator.shared
        
        // Check authentication status (simulating app launch)
        mockAPIService.mockResponses["/users/me"] = testUser
        mockAPIService.mockResponses["/profiles"] = [testProfile]
        
        newAuthManager.checkAuthenticationStatus()
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify session is restored
        XCTAssertTrue(newAuthManager.isAuthenticated)
        XCTAssertNotNil(newAuthManager.currentUser)
        XCTAssertEqual(newSessionCoordinator.sessionState, .authenticated)
    }
}