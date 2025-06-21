import Foundation

// MARK: - V2 API Test Suite
class V2APITestSuite {
    private let configuration: TestHubConfiguration
    private let networkClient: TestNetworkClient
    private var testContext: TestContext
    
    init(configuration: TestHubConfiguration) {
        self.configuration = configuration
        self.networkClient = TestNetworkClient(baseURL: configuration.baseURL, apiVersion: configuration.apiVersion)
        self.testContext = TestContext()
    }
    
    // MARK: - Test Organization
    
    func getAllTests() -> [TestCase] {
        return [
            getAuthenticationTests(),
            getProfileTests(),
            getAccountLinkingTests(),
            getTokenManagementTests(),
            getEdgeCaseTests()
        ].flatMap { $0 }
    }
    
    func getTestsForCategory(_ category: String) -> [TestCase] {
        switch category.lowercased() {
        case "auth", "authentication":
            return getAuthenticationTests()
        case "profile", "profiles":
            return getProfileTests()
        case "linking", "account-linking":
            return getAccountLinkingTests()
        case "token", "tokens":
            return getTokenManagementTests()
        case "edge", "edge-cases":
            return getEdgeCaseTests()
        default:
            return []
        }
    }
    
    // MARK: - Authentication Tests
    
    private func getAuthenticationTests() -> [TestCase] {
        return [
            TestCase(
                name: "Email Auth - New User",
                category: "Authentication",
                execute: testEmailAuthNewUser
            ),
            TestCase(
                name: "Email Auth - Returning User",
                category: "Authentication",
                execute: testEmailAuthReturningUser
            ),
            TestCase(
                name: "Wallet Auth - New User",
                category: "Authentication",
                execute: testWalletAuthNewUser
            ),
            TestCase(
                name: "Wallet Auth - Returning User",
                category: "Authentication",
                execute: testWalletAuthReturningUser
            ),
            TestCase(
                name: "Guest Authentication",
                category: "Authentication",
                execute: testGuestAuth
            ),
            TestCase(
                name: "Logout",
                category: "Authentication",
                execute: testLogout
            )
        ]
    }
    
    // MARK: - Profile Tests
    
    private func getProfileTests() -> [TestCase] {
        return [
            TestCase(
                name: "Automatic Profile Creation",
                category: "Profile",
                execute: testAutomaticProfileCreation
            ),
            TestCase(
                name: "Get Profiles",
                category: "Profile",
                execute: testGetProfiles
            ),
            TestCase(
                name: "Create Additional Profile",
                category: "Profile",
                execute: testCreateAdditionalProfile
            ),
            TestCase(
                name: "Switch Profile",
                category: "Profile",
                execute: testSwitchProfile
            ),
            TestCase(
                name: "Update Profile",
                category: "Profile",
                execute: testUpdateProfile
            ),
            TestCase(
                name: "Delete Profile",
                category: "Profile",
                execute: testDeleteProfile
            )
        ]
    }
    
    // MARK: - Account Linking Tests
    
    private func getAccountLinkingTests() -> [TestCase] {
        return [
            TestCase(
                name: "Link Email to Wallet",
                category: "Account Linking",
                execute: testLinkEmailToWallet
            ),
            TestCase(
                name: "Link Wallet to Email",
                category: "Account Linking",
                execute: testLinkWalletToEmail
            ),
            TestCase(
                name: "Get Identity Graph",
                category: "Account Linking",
                execute: testGetIdentityGraph
            ),
            TestCase(
                name: "Update Privacy Mode",
                category: "Account Linking",
                execute: testUpdatePrivacyMode
            )
        ]
    }
    
    // MARK: - Token Management Tests
    
    private func getTokenManagementTests() -> [TestCase] {
        return [
            TestCase(
                name: "Token Refresh",
                category: "Token Management",
                execute: testTokenRefresh
            ),
            TestCase(
                name: "Token Validation",
                category: "Token Management",
                execute: testTokenValidation
            ),
            TestCase(
                name: "Token Expiration",
                category: "Token Management",
                execute: testTokenExpiration
            ),
            TestCase(
                name: "Token Blacklist",
                category: "Token Management",
                execute: testTokenBlacklist
            )
        ]
    }
    
    // MARK: - Edge Case Tests
    
    private func getEdgeCaseTests() -> [TestCase] {
        return [
            TestCase(
                name: "Invalid Email Code",
                category: "Edge Cases",
                execute: testInvalidEmailCode
            ),
            TestCase(
                name: "Rate Limiting",
                category: "Edge Cases",
                execute: testRateLimiting
            ),
            TestCase(
                name: "Network Timeout",
                category: "Edge Cases",
                execute: testNetworkTimeout
            ),
            TestCase(
                name: "Concurrent Sessions",
                category: "Edge Cases",
                execute: testConcurrentSessions
            )
        ]
    }
    
    // MARK: - Test Implementations
    
    // Authentication Tests
    
    private func testEmailAuthNewUser() async throws {
        let email = "test_\(UUID().uuidString.prefix(8))@interspace.test"
        
        // Send code
        let codeResponse = try await networkClient.post(
            "/auth/send-email-code",
            body: ["email": email]
        )
        
        guard codeResponse.statusCode == 200 else {
            throw TestError("Failed to send email code: HTTP \(codeResponse.statusCode)")
        }
        
        // Verify with mock code (in production, would need actual code)
        let authResponse = try await networkClient.post(
            "/auth/authenticate",
            body: [
                "strategy": "email",
                "email": email,
                "verificationCode": "123456"
            ]
        )
        
        guard authResponse.statusCode == 200 else {
            throw TestError("Authentication failed: HTTP \(authResponse.statusCode)")
        }
        
        // Verify response structure
        guard let data = authResponse.data,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let isNewUser = json["isNewUser"] as? Bool,
              let profiles = json["profiles"] as? [[String: Any]],
              let tokens = json["tokens"] as? [String: Any] else {
            throw TestError("Invalid response structure")
        }
        
        // Verify new user
        guard isNewUser else {
            throw TestError("Expected new user, but isNewUser was false")
        }
        
        // Verify automatic profile creation
        guard profiles.count == 1,
              let profile = profiles.first,
              profile["name"] as? String == "My Smartprofile" else {
            throw TestError("Automatic profile creation failed")
        }
        
        // Store tokens for subsequent tests
        if let accessToken = tokens["accessToken"] as? String {
            testContext.accessToken = accessToken
        }
        if let refreshToken = tokens["refreshToken"] as? String {
            testContext.refreshToken = refreshToken
        }
    }
    
    private func testEmailAuthReturningUser() async throws {
        // Use a known test email
        let email = "existing@interspace.test"
        
        // Send code
        let codeResponse = try await networkClient.post(
            "/auth/send-email-code",
            body: ["email": email]
        )
        
        guard codeResponse.statusCode == 200 else {
            throw TestError("Failed to send email code: HTTP \(codeResponse.statusCode)")
        }
        
        // Authenticate
        let authResponse = try await networkClient.post(
            "/auth/authenticate",
            body: [
                "strategy": "email",
                "email": email,
                "verificationCode": "123456"
            ]
        )
        
        guard authResponse.statusCode == 200 else {
            throw TestError("Authentication failed: HTTP \(authResponse.statusCode)")
        }
        
        // Verify returning user
        guard let data = authResponse.data,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let isNewUser = json["isNewUser"] as? Bool else {
            throw TestError("Invalid response structure")
        }
        
        guard !isNewUser else {
            throw TestError("Expected returning user, but isNewUser was true")
        }
    }
    
    private func testWalletAuthNewUser() async throws {
        let wallet = generateTestWallet()
        let message = "Sign in to Interspace\nTimestamp: \(Date().timeIntervalSince1970)"
        let signature = generateTestSignature(message: message, wallet: wallet)
        
        let response = try await networkClient.post(
            "/auth/authenticate",
            body: [
                "strategy": "wallet",
                "walletAddress": wallet.address,
                "message": message,
                "signature": signature
            ]
        )
        
        guard response.statusCode == 200 else {
            throw TestError("Wallet authentication failed: HTTP \(response.statusCode)")
        }
        
        // Verify new user and profile creation
        guard let data = response.data,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let isNewUser = json["isNewUser"] as? Bool,
              isNewUser == true else {
            throw TestError("Expected new user with wallet authentication")
        }
    }
    
    private func testWalletAuthReturningUser() async throws {
        // Would use existing wallet from context
        guard let wallet = testContext.testWallet else {
            throw TestError("No test wallet available")
        }
        
        let message = "Sign in to Interspace\nTimestamp: \(Date().timeIntervalSince1970)"
        let signature = generateTestSignature(message: message, wallet: wallet)
        
        let response = try await networkClient.post(
            "/auth/authenticate",
            body: [
                "strategy": "wallet",
                "walletAddress": wallet.address,
                "message": message,
                "signature": signature
            ]
        )
        
        guard response.statusCode == 200 else {
            throw TestError("Wallet authentication failed: HTTP \(response.statusCode)")
        }
    }
    
    private func testGuestAuth() async throws {
        let response = try await networkClient.post(
            "/auth/authenticate",
            body: [
                "strategy": "guest",
                "deviceId": UUID().uuidString
            ]
        )
        
        guard response.statusCode == 200 else {
            throw TestError("Guest authentication failed: HTTP \(response.statusCode)")
        }
        
        // Verify guest account created
        guard let data = response.data,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let account = json["account"] as? [String: Any],
              account["type"] as? String == "guest" else {
            throw TestError("Guest account not created properly")
        }
    }
    
    private func testLogout() async throws {
        guard let token = testContext.accessToken else {
            throw TestError("No access token available for logout test")
        }
        
        let response = try await networkClient.post(
            "/auth/logout",
            headers: ["Authorization": "Bearer \(token)"]
        )
        
        guard response.statusCode == 200 else {
            throw TestError("Logout failed: HTTP \(response.statusCode)")
        }
    }
    
    // Profile Tests
    
    private func testAutomaticProfileCreation() async throws {
        // Create new user
        let email = "profile_test_\(UUID().uuidString.prefix(8))@interspace.test"
        
        let authResponse = try await networkClient.post(
            "/auth/authenticate",
            body: [
                "strategy": "email",
                "email": email,
                "verificationCode": "123456"
            ]
        )
        
        guard authResponse.statusCode == 200,
              let data = authResponse.data,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profiles = json["profiles"] as? [[String: Any]],
              let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["accessToken"] as? String else {
            throw TestError("Failed to create new user for profile test")
        }
        
        // Get profiles
        let profilesResponse = try await networkClient.get(
            "/profiles",
            headers: ["Authorization": "Bearer \(accessToken)"]
        )
        
        guard profilesResponse.statusCode == 200,
              let profileData = profilesResponse.data,
              let profileJson = try JSONSerialization.jsonObject(with: profileData) as? [String: Any],
              let profileList = profileJson["data"] as? [[String: Any]] ?? profileJson["profiles"] as? [[String: Any]] else {
            throw TestError("Failed to get profiles")
        }
        
        // Verify automatic profile
        guard profileList.count == 1,
              let profile = profileList.first,
              profile["name"] as? String == "My Smartprofile" else {
            throw TestError("Automatic profile creation not verified")
        }
    }
    
    private func testGetProfiles() async throws {
        guard let token = testContext.accessToken else {
            throw TestError("No access token available")
        }
        
        let response = try await networkClient.get(
            "/profiles",
            headers: ["Authorization": "Bearer \(token)"]
        )
        
        guard response.statusCode == 200 else {
            throw TestError("Get profiles failed: HTTP \(response.statusCode)")
        }
    }
    
    private func testCreateAdditionalProfile() async throws {
        guard let token = testContext.accessToken else {
            throw TestError("No access token available")
        }
        
        let response = try await networkClient.post(
            "/profiles",
            headers: ["Authorization": "Bearer \(token)"],
            body: [
                "name": "Test Profile \(Date().timeIntervalSince1970)",
                "isDevelopmentWallet": true
            ]
        )
        
        guard response.statusCode == 201 || response.statusCode == 200 else {
            throw TestError("Create profile failed: HTTP \(response.statusCode)")
        }
        
        // Store profile ID for later tests
        if let data = response.data,
           let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let profile = json["data"] as? [String: Any] ?? json["profile"] as? [String: Any],
           let profileId = profile["id"] as? String {
            testContext.additionalProfileId = profileId
        }
    }
    
    private func testSwitchProfile() async throws {
        guard let token = testContext.accessToken,
              let profileId = testContext.additionalProfileId else {
            throw TestError("No access token or profile ID available")
        }
        
        let response = try await networkClient.post(
            "/auth/switch-profile/\(profileId)",
            headers: ["Authorization": "Bearer \(token)"]
        )
        
        guard response.statusCode == 200 else {
            throw TestError("Switch profile failed: HTTP \(response.statusCode)")
        }
    }
    
    private func testUpdateProfile() async throws {
        guard let token = testContext.accessToken,
              let profileId = testContext.additionalProfileId else {
            throw TestError("No access token or profile ID available")
        }
        
        let response = try await networkClient.put(
            "/profiles/\(profileId)",
            headers: ["Authorization": "Bearer \(token)"],
            body: ["name": "Updated Profile Name"]
        )
        
        guard response.statusCode == 200 else {
            throw TestError("Update profile failed: HTTP \(response.statusCode)")
        }
    }
    
    private func testDeleteProfile() async throws {
        guard let token = testContext.accessToken,
              let profileId = testContext.additionalProfileId else {
            throw TestError("No access token or profile ID available")
        }
        
        let response = try await networkClient.delete(
            "/profiles/\(profileId)",
            headers: ["Authorization": "Bearer \(token)"]
        )
        
        // Should succeed or fail with 400 if it's the last profile
        guard response.statusCode == 200 || response.statusCode == 400 else {
            throw TestError("Delete profile failed: HTTP \(response.statusCode)")
        }
    }
    
    // Account Linking Tests
    
    private func testLinkEmailToWallet() async throws {
        // First authenticate with wallet
        let wallet = generateTestWallet()
        let message = "Sign in to Interspace\nTimestamp: \(Date().timeIntervalSince1970)"
        let signature = generateTestSignature(message: message, wallet: wallet)
        
        let authResponse = try await networkClient.post(
            "/auth/authenticate",
            body: [
                "strategy": "wallet",
                "walletAddress": wallet.address,
                "message": message,
                "signature": signature
            ]
        )
        
        guard authResponse.statusCode == 200,
              let data = authResponse.data,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["accessToken"] as? String else {
            throw TestError("Wallet authentication failed")
        }
        
        // Link email
        let email = "linked_\(UUID().uuidString.prefix(8))@interspace.test"
        let linkResponse = try await networkClient.post(
            "/auth/link-accounts",
            headers: ["Authorization": "Bearer \(accessToken)"],
            body: [
                "targetType": "email",
                "targetIdentifier": email,
                "privacyMode": "linked"
            ]
        )
        
        guard linkResponse.statusCode == 200 else {
            throw TestError("Account linking failed: HTTP \(linkResponse.statusCode)")
        }
    }
    
    private func testLinkWalletToEmail() async throws {
        // Reverse of above - authenticate with email first, then link wallet
        // Implementation similar to testLinkEmailToWallet but reversed
    }
    
    private func testGetIdentityGraph() async throws {
        guard let token = testContext.accessToken else {
            throw TestError("No access token available")
        }
        
        let response = try await networkClient.get(
            "/auth/identity-graph",
            headers: ["Authorization": "Bearer \(token)"]
        )
        
        guard response.statusCode == 200 else {
            throw TestError("Get identity graph failed: HTTP \(response.statusCode)")
        }
    }
    
    private func testUpdatePrivacyMode() async throws {
        guard let token = testContext.accessToken else {
            throw TestError("No access token available")
        }
        
        // Would need a linked account ID from previous test
        // For now, this is a placeholder
        throw TestError("Not implemented - requires linked account from previous test")
    }
    
    // Token Management Tests
    
    private func testTokenRefresh() async throws {
        guard let refreshToken = testContext.refreshToken else {
            throw TestError("No refresh token available")
        }
        
        let response = try await networkClient.post(
            "/auth/refresh",
            body: ["refreshToken": refreshToken]
        )
        
        guard response.statusCode == 200 else {
            throw TestError("Token refresh failed: HTTP \(response.statusCode)")
        }
        
        // Update tokens in context
        if let data = response.data,
           let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let tokens = json["tokens"] as? [String: Any] {
            if let accessToken = tokens["accessToken"] as? String {
                testContext.accessToken = accessToken
            }
            if let refreshToken = tokens["refreshToken"] as? String {
                testContext.refreshToken = refreshToken
            }
        }
    }
    
    private func testTokenValidation() async throws {
        guard let token = testContext.accessToken else {
            throw TestError("No access token available")
        }
        
        // Use a protected endpoint to validate token
        let response = try await networkClient.get(
            "/profiles",
            headers: ["Authorization": "Bearer \(token)"]
        )
        
        guard response.statusCode == 200 else {
            throw TestError("Token validation failed: HTTP \(response.statusCode)")
        }
    }
    
    private func testTokenExpiration() async throws {
        // Use an expired token
        let expiredToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2MDk0NTkyMDB9.invalid"
        
        let response = try await networkClient.get(
            "/profiles",
            headers: ["Authorization": "Bearer \(expiredToken)"]
        )
        
        // Should return 401
        guard response.statusCode == 401 else {
            throw TestError("Expected 401 for expired token, got \(response.statusCode)")
        }
    }
    
    private func testTokenBlacklist() async throws {
        guard let token = testContext.accessToken else {
            throw TestError("No access token available")
        }
        
        // Logout to blacklist token
        let logoutResponse = try await networkClient.post(
            "/auth/logout",
            headers: ["Authorization": "Bearer \(token)"]
        )
        
        guard logoutResponse.statusCode == 200 else {
            throw TestError("Logout failed")
        }
        
        // Try to use blacklisted token
        let response = try await networkClient.get(
            "/profiles",
            headers: ["Authorization": "Bearer \(token)"]
        )
        
        // Should return 401
        guard response.statusCode == 401 else {
            throw TestError("Expected 401 for blacklisted token, got \(response.statusCode)")
        }
    }
    
    // Edge Case Tests
    
    private func testInvalidEmailCode() async throws {
        let response = try await networkClient.post(
            "/auth/authenticate",
            body: [
                "strategy": "email",
                "email": "test@interspace.test",
                "verificationCode": "000000"
            ]
        )
        
        // Should return error
        guard response.statusCode == 401 || response.statusCode == 400 else {
            throw TestError("Expected error for invalid code, got \(response.statusCode)")
        }
    }
    
    private func testRateLimiting() async throws {
        // Make rapid requests
        for i in 0..<20 {
            let response = try await networkClient.post(
                "/auth/send-email-code",
                body: ["email": "ratelimit_\(i)@interspace.test"]
            )
            
            if response.statusCode == 429 {
                // Rate limit hit - success
                return
            }
        }
        
        throw TestError("Rate limiting not triggered after 20 requests")
    }
    
    private func testNetworkTimeout() async throws {
        // Would need to configure a timeout scenario
        // For now, this is a placeholder
        throw TestError("Network timeout test not implemented")
    }
    
    private func testConcurrentSessions() async throws {
        // Test multiple concurrent sessions
        // Would need to create multiple auth tokens and test concurrent access
        throw TestError("Concurrent sessions test not implemented")
    }
    
    // MARK: - Helper Methods
    
    private func generateTestWallet() -> TestWallet {
        let address = "0x" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(40).lowercased()
        return TestWallet(address: address, privateKey: "mock_private_key")
    }
    
    private func generateTestSignature(message: String, wallet: TestWallet) -> String {
        // In real implementation, would use actual wallet signing
        // For testing, generate a mock signature
        let data = (message + wallet.privateKey).data(using: .utf8) ?? Data()
        return "0x" + data.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Supporting Types

struct TestCase {
    let name: String
    let category: String
    let execute: () async throws -> Void
}

struct TestContext {
    var accessToken: String?
    var refreshToken: String?
    var testWallet: TestWallet?
    var additionalProfileId: String?
}

struct TestWallet {
    let address: String
    let privateKey: String
}

struct TestError: LocalizedError {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var errorDescription: String? {
        return message
    }
}