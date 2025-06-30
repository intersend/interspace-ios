import XCTest
@testable import Interspace

class AuthModelsTests: XCTestCase {
    
    // MARK: - AuthStrategy Tests
    
    func testAuthStrategyDisplayNames() {
        XCTAssertEqual(AuthStrategy.wallet.displayName, "Wallet")
        XCTAssertEqual(AuthStrategy.email.displayName, "Email")
        XCTAssertEqual(AuthStrategy.google.displayName, "Google")
        XCTAssertEqual(AuthStrategy.apple.displayName, "Apple")
        XCTAssertEqual(AuthStrategy.passkey.displayName, "Passkey")
        XCTAssertEqual(AuthStrategy.guest.displayName, "Guest")
        XCTAssertEqual(AuthStrategy.testWallet.displayName, "Test Wallet")
    }
    
    func testAuthStrategyIcons() {
        XCTAssertEqual(AuthStrategy.wallet.icon, "wallet.pass.fill")
        XCTAssertEqual(AuthStrategy.email.icon, "envelope.fill")
        XCTAssertEqual(AuthStrategy.google.icon, "globe")
        XCTAssertEqual(AuthStrategy.apple.icon, "apple.logo")
        XCTAssertEqual(AuthStrategy.passkey.icon, "person.crop.circle.fill.badge.checkmark")
        XCTAssertEqual(AuthStrategy.guest.icon, "person.fill")
        XCTAssertEqual(AuthStrategy.testWallet.icon, "testtube.2")
    }
    
    func testAuthStrategyDescriptions() {
        XCTAssertEqual(AuthStrategy.wallet.description, "Connect using MetaMask or Coinbase")
        XCTAssertEqual(AuthStrategy.email.description, "Sign in with email verification")
        XCTAssertEqual(AuthStrategy.google.description, "Continue with Google account")
        XCTAssertEqual(AuthStrategy.apple.description, "Continue with Apple ID")
        XCTAssertEqual(AuthStrategy.passkey.description, "Use biometric authentication")
        XCTAssertEqual(AuthStrategy.guest.description, "Browse without an account")
        XCTAssertEqual(AuthStrategy.testWallet.description, "Development testing only")
    }
    
    func testAuthStrategyCodable() throws {
        // Test encoding
        let strategies: [AuthStrategy] = [.wallet, .email, .google]
        let encoder = JSONEncoder()
        let data = try encoder.encode(strategies)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedStrategies = try decoder.decode([AuthStrategy].self, from: data)
        
        XCTAssertEqual(strategies, decodedStrategies)
    }
    
    // MARK: - AuthenticationRequest Tests
    
    func testAuthenticationRequestCreation() {
        let request = AuthenticationRequest(
            authToken: "test-token",
            authStrategy: "wallet",
            deviceId: "device-123",
            deviceName: "Test Device",
            walletAddress: "0x1234",
            email: nil,
            verificationCode: nil
        )
        
        XCTAssertEqual(request.authToken, "test-token")
        XCTAssertEqual(request.authStrategy, "wallet")
        XCTAssertEqual(request.deviceId, "device-123")
        XCTAssertEqual(request.deviceName, "Test Device")
        XCTAssertEqual(request.deviceType, "ios")
        XCTAssertEqual(request.walletAddress, "0x1234")
        XCTAssertNil(request.email)
        XCTAssertNil(request.verificationCode)
    }
    
    func testAuthenticationRequestCodable() throws {
        let request = AuthenticationRequest(
            authToken: "test-token",
            authStrategy: "email",
            deviceId: "device-123",
            deviceName: "Test Device",
            walletAddress: nil,
            email: "test@example.com",
            verificationCode: "123456"
        )
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedRequest = try decoder.decode(AuthenticationRequest.self, from: data)
        
        XCTAssertEqual(request.authToken, decodedRequest.authToken)
        XCTAssertEqual(request.authStrategy, decodedRequest.authStrategy)
        XCTAssertEqual(request.email, decodedRequest.email)
        XCTAssertEqual(request.verificationCode, decodedRequest.verificationCode)
    }
    
    // MARK: - User Model Tests
    
    func testUserModelCreation() {
        let user = User(
            id: "user-123",
            email: "test@example.com",
            walletAddress: "0x1234",
            isGuest: false,
            authStrategies: ["email", "wallet"],
            profilesCount: 2,
            linkedAccountsCount: 3,
            activeDevicesCount: 1,
            socialAccounts: [],
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-02T00:00:00Z"
        )
        
        XCTAssertEqual(user.id, "user-123")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.walletAddress, "0x1234")
        XCTAssertFalse(user.isGuest)
        XCTAssertEqual(user.authStrategies, ["email", "wallet"])
        XCTAssertEqual(user.profilesCount, 2)
        XCTAssertEqual(user.linkedAccountsCount, 3)
        XCTAssertEqual(user.activeDevicesCount, 1)
    }
    
    func testGuestUserModel() {
        let guestUser = User(
            id: "guest-123",
            email: nil,
            walletAddress: nil,
            isGuest: true,
            authStrategies: ["guest"],
            profilesCount: 0,
            linkedAccountsCount: 0,
            activeDevicesCount: 1,
            socialAccounts: [],
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
        
        XCTAssertTrue(guestUser.isGuest)
        XCTAssertNil(guestUser.email)
        XCTAssertNil(guestUser.walletAddress)
        XCTAssertEqual(guestUser.authStrategies, ["guest"])
        XCTAssertEqual(guestUser.profilesCount, 0)
    }
    
    // MARK: - AuthenticationError Tests
    
    func testAuthenticationErrorIdentifiers() {
        let error1 = AuthenticationError.invalidCredentials
        let error2 = AuthenticationError.networkError("Connection failed")
        let error3 = AuthenticationError.walletConnectionFailed("MetaMask error")
        
        XCTAssertEqual(error1.id, "invalidCredentials")
        XCTAssertEqual(error2.id, "networkError-Connection failed")
        XCTAssertEqual(error3.id, "walletConnectionFailed-MetaMask error")
    }
    
    func testAuthenticationErrorDescriptions() {
        XCTAssertEqual(
            AuthenticationError.invalidCredentials.errorDescription,
            "Invalid credentials. Please try again."
        )
        
        XCTAssertEqual(
            AuthenticationError.networkError("Timeout").errorDescription,
            "Network error: Timeout"
        )
        
        XCTAssertEqual(
            AuthenticationError.walletConnectionFailed("User rejected").errorDescription,
            "Wallet connection failed: User rejected"
        )
        
        XCTAssertEqual(
            AuthenticationError.emailVerificationFailed.errorDescription,
            "Email verification failed. Please check your code."
        )
        
        XCTAssertEqual(
            AuthenticationError.tokenExpired.errorDescription,
            "Your session has expired. Please sign in again."
        )
        
        XCTAssertEqual(
            AuthenticationError.unknown("Custom error").errorDescription,
            "Custom error"
        )
    }
    
    // MARK: - WalletConnectionConfig Tests
    
    func testWalletConnectionConfigCreation() {
        let config = WalletConnectionConfig(
            strategy: .wallet,
            walletType: "metamask",
            email: nil,
            verificationCode: nil,
            walletAddress: "0x1234",
            signature: "0xsignature",
            message: nil,
            socialProvider: nil,
            socialProfile: nil,
            oauthCode: nil,
            idToken: nil,
            accessToken: nil,
            shopDomain: nil
        )
        
        XCTAssertEqual(config.strategy, .wallet)
        XCTAssertEqual(config.walletType, "metamask")
        XCTAssertEqual(config.walletAddress, "0x1234")
        XCTAssertEqual(config.signature, "0xsignature")
        XCTAssertNil(config.email)
        XCTAssertNil(config.socialProvider)
    }
    
    func testEmailConnectionConfig() {
        let config = WalletConnectionConfig(
            strategy: .email,
            walletType: nil,
            email: "test@example.com",
            verificationCode: "123456",
            walletAddress: nil,
            signature: nil,
            message: nil,
            socialProvider: nil,
            socialProfile: nil,
            oauthCode: nil,
            idToken: nil,
            accessToken: nil,
            shopDomain: nil
        )
        
        XCTAssertEqual(config.strategy, .email)
        XCTAssertEqual(config.email, "test@example.com")
        XCTAssertEqual(config.verificationCode, "123456")
        XCTAssertNil(config.walletType)
        XCTAssertNil(config.walletAddress)
    }
    
    func testSocialConnectionConfig() {
        let socialProfile = SocialProfile(
            id: "google-123",
            email: "test@gmail.com",
            name: "Test User",
            picture: "https://example.com/avatar.jpg"
        )
        
        let config = WalletConnectionConfig(
            strategy: .google,
            walletType: nil,
            email: "test@gmail.com",
            verificationCode: nil,
            walletAddress: nil,
            signature: nil,
            message: nil,
            socialProvider: "google",
            socialProfile: socialProfile,
            oauthCode: nil,
            idToken: nil,
            accessToken: nil,
            shopDomain: nil
        )
        
        XCTAssertEqual(config.strategy, .google)
        XCTAssertEqual(config.socialProvider, "google")
        XCTAssertEqual(config.socialProfile?.id, "google-123")
        XCTAssertEqual(config.socialProfile?.email, "test@gmail.com")
        XCTAssertEqual(config.socialProfile?.name, "Test User")
    }
    
    // MARK: - DeviceInfo Tests
    
    func testDeviceInfoConsistency() {
        // Get device ID multiple times
        let deviceId1 = DeviceInfo.deviceId
        let deviceId2 = DeviceInfo.deviceId
        
        // Should be the same (persisted)
        XCTAssertEqual(deviceId1, deviceId2)
        XCTAssertFalse(deviceId1.isEmpty)
        
        // Verify it's a valid UUID
        XCTAssertNotNil(UUID(uuidString: deviceId1))
    }
    
    func testDeviceInfoProperties() {
        XCTAssertFalse(DeviceInfo.deviceName.isEmpty)
        XCTAssertEqual(DeviceInfo.deviceType, "ios")
    }
}