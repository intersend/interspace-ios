import XCTest
import Combine
@testable import Interspace

@MainActor
class AuthViewModelTests: XCTestCase {
    
    var sut: AuthViewModel!
    var mockAuthManager: AuthenticationManager!
    var mockWalletService: WalletService!
    var mockAPIService: MockAPIService!
    var mockKeychainManager: MockKeychainManager!
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
        mockAuthManager = AuthenticationManager.shared
        mockWalletService = WalletService.shared
        
        // Create SUT
        sut = AuthViewModel()
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        mockAPIService.reset()
        mockKeychainManager.reset()
        sut = nil
        await super.tearDown()
    }
    
    // MARK: - Authentication Strategy Tests
    
    func testSelectWalletStrategy() {
        // When
        sut.selectAuthStrategy(.wallet)
        
        // Then
        XCTAssertEqual(sut.selectedAuthStrategy, .wallet)
        XCTAssertTrue(sut.showWalletTray)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.showError)
    }
    
    func testSelectEmailStrategy() {
        // When
        sut.selectAuthStrategy(.email)
        
        // Then
        XCTAssertEqual(sut.selectedAuthStrategy, .email)
        XCTAssertFalse(sut.showWalletTray)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.showError)
    }
    
    func testSelectGuestStrategy() async throws {
        // Given
        let authResponse = TestDataFactory.createAuthResponse()
        mockAPIService.mockResponses["/auth/authenticate"] = authResponse
        
        // When
        sut.selectAuthStrategy(.guest)
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(sut.selectedAuthStrategy, .guest)
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/auth/authenticate", method: .POST))
    }
    
    // MARK: - Email Authentication Tests
    
    func testSendEmailCodeWithValidEmail() async throws {
        // Given
        sut.email = "test@example.com"
        mockAPIService.mockResponses["/auth/send-code"] = EmailCodeResponse(success: true, message: "Code sent")
        
        // When
        sut.sendEmailCode()
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertTrue(sut.isEmailCodeSent)
        XCTAssertFalse(sut.canResendEmail)
        XCTAssertTrue(sut.emailResendTimer > 0)
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/auth/send-code", method: .POST))
    }
    
    func testSendEmailCodeWithInvalidEmail() {
        // Given
        sut.email = "invalid-email"
        
        // When
        sut.sendEmailCode()
        
        // Then
        XCTAssertNotNil(sut.error)
        XCTAssertTrue(sut.showError)
        XCTAssertFalse(sut.isEmailCodeSent)
        
        if case .emailVerificationFailed = sut.error {
            // Expected
        } else {
            XCTFail("Expected emailVerificationFailed error")
        }
    }
    
    func testVerifyEmailCode() async throws {
        // Given
        sut.email = "test@example.com"
        sut.verificationCode = "123456"
        
        let authResponse = TestDataFactory.createAuthResponse()
        let testUser = TestDataFactory.createTestUser(email: "test@example.com")
        
        mockAPIService.mockResponses["/auth/authenticate"] = authResponse
        mockAPIService.mockResponses["/users/me"] = testUser
        
        // When
        sut.verifyEmailCode()
        
        // Wait for async operations
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Then
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/auth/authenticate", method: .POST))
        
        if let requestBody = mockAPIService.getLastRequestBody(for: "/auth/authenticate", as: AuthenticationRequest.self) {
            XCTAssertEqual(requestBody.email, "test@example.com")
            XCTAssertEqual(requestBody.verificationCode, "123456")
            XCTAssertEqual(requestBody.authStrategy, "email")
        }
    }
    
    func testVerifyEmailCodeWithInvalidCode() {
        // Given
        sut.email = "test@example.com"
        sut.verificationCode = "123" // Too short
        
        // When
        sut.verifyEmailCode()
        
        // Then
        XCTAssertNotNil(sut.error)
        XCTAssertTrue(sut.showError)
        
        if case .emailVerificationFailed = sut.error {
            // Expected
        } else {
            XCTFail("Expected emailVerificationFailed error")
        }
    }
    
    // MARK: - Email Resend Timer Tests
    
    func testEmailResendTimer() async throws {
        // Given
        sut.email = "test@example.com"
        mockAPIService.mockResponses["/auth/send-code"] = EmailCodeResponse(success: true, message: "Code sent")
        
        // When
        sut.sendEmailCode()
        
        // Then - Timer should start
        XCTAssertFalse(sut.canResendEmail)
        XCTAssertEqual(sut.emailResendTimer, 60)
        
        // Wait for timer to count down (testing with shorter wait)
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Timer should have decreased
        XCTAssertTrue(sut.emailResendTimer < 60)
    }
    
    // MARK: - Wallet Selection Tests
    
    func testSelectWallet() async throws {
        // Given
        let walletResult = WalletConnectionResult(
            address: "0x1234567890",
            signature: "0xsignature",
            chainId: "1",
            walletType: .metamask
        )
        
        // Mock wallet connection success
        let authResponse = TestDataFactory.createAuthResponse()
        let testUser = TestDataFactory.createTestUser(walletAddress: walletResult.address)
        
        mockAPIService.mockResponses["/auth/authenticate"] = authResponse
        mockAPIService.mockResponses["/users/me"] = testUser
        
        // When
        sut.selectWallet(.metamask)
        
        // Then
        XCTAssertEqual(sut.selectedWalletType, .metamask)
        XCTAssertFalse(sut.showWalletTray)
    }
    
    // MARK: - UI State Tests
    
    func testDismissError() {
        // Given
        sut.error = AuthenticationError.invalidCredentials
        sut.showError = true
        
        // When
        sut.dismissError()
        
        // Then
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.showError)
    }
    
    func testDismissWalletTray() {
        // Given
        sut.showWalletTray = true
        sut.selectedWalletType = .metamask
        
        // When
        sut.dismissWalletTray()
        
        // Then
        XCTAssertFalse(sut.showWalletTray)
        XCTAssertNil(sut.selectedWalletType)
    }
    
    func testResetAuthFlow() {
        // Given
        sut.selectedAuthStrategy = .email
        sut.email = "test@example.com"
        sut.verificationCode = "123456"
        sut.isEmailCodeSent = true
        sut.selectedWalletType = .metamask
        sut.error = AuthenticationError.invalidCredentials
        sut.showError = true
        sut.showWalletTray = true
        
        // When
        sut.resetAuthFlow()
        
        // Then
        XCTAssertNil(sut.selectedAuthStrategy)
        XCTAssertEqual(sut.email, "")
        XCTAssertEqual(sut.verificationCode, "")
        XCTAssertFalse(sut.isEmailCodeSent)
        XCTAssertNil(sut.selectedWalletType)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.showError)
        XCTAssertFalse(sut.showWalletTray)
        XCTAssertTrue(sut.canResendEmail)
        XCTAssertEqual(sut.emailResendTimer, 0)
    }
    
    // MARK: - Computed Properties Tests
    
    func testIsEmailValid() {
        // Test invalid emails
        sut.email = ""
        XCTAssertFalse(sut.isEmailValid)
        
        sut.email = "invalid"
        XCTAssertFalse(sut.isEmailValid)
        
        sut.email = "test@"
        XCTAssertFalse(sut.isEmailValid)
        
        sut.email = "@example.com"
        XCTAssertFalse(sut.isEmailValid)
        
        // Test valid emails
        sut.email = "test@example.com"
        XCTAssertTrue(sut.isEmailValid)
        
        sut.email = "user.name+tag@example.co.uk"
        XCTAssertTrue(sut.isEmailValid)
    }
    
    func testIsVerificationCodeValid() {
        // Test invalid codes
        sut.verificationCode = ""
        XCTAssertFalse(sut.isVerificationCodeValid)
        
        sut.verificationCode = "12345" // Too short
        XCTAssertFalse(sut.isVerificationCodeValid)
        
        sut.verificationCode = "1234567" // Too long
        XCTAssertFalse(sut.isVerificationCodeValid)
        
        sut.verificationCode = "12345a" // Contains letter
        XCTAssertFalse(sut.isVerificationCodeValid)
        
        // Test valid code
        sut.verificationCode = "123456"
        XCTAssertTrue(sut.isVerificationCodeValid)
    }
    
    func testEmailResendText() {
        // When can resend
        sut.canResendEmail = true
        XCTAssertEqual(sut.emailResendText, "Resend Code")
        
        // When cannot resend
        sut.canResendEmail = false
        sut.emailResendTimer = 45
        XCTAssertEqual(sut.emailResendText, "Resend in 45s")
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingStateBinding() {
        // Create observer
        let loadingObserver = TestObserver<Bool>()
        loadingObserver.observe(sut.$isLoading)
        
        // When auth manager updates loading state
        mockAuthManager.isLoading = true
        
        // Then
        XCTAssertTrue(sut.isLoading)
        XCTAssertTrue(loadingObserver.values.contains(true))
        
        // When loading completes
        mockAuthManager.isLoading = false
        
        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertTrue(loadingObserver.values.contains(false))
    }
}