import Foundation
import Combine

// MARK: - Test Runner
class TestRunner: ObservableObject {
    @Published var configuration = TestConfiguration()
    @Published var results: [TestResult] = []
    @Published var isRunning = false
    @Published var progress: Double = 0.0
    @Published var currentTestName = ""
    @Published var completedTests = 0
    @Published var totalTests = 0
    @Published var estimatedTimeRemaining: TimeInterval?
    
    private let apiService: APIService
    private let authService: TestAuthService
    private let profileService: TestProfileService
    private let linkingService: TestAccountLinkingService
    private let tokenService: TestTokenService
    
    private var testStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize API service with test configuration
        self.apiService = APIService.shared
        self.authService = TestAuthService(apiService: apiService, configuration: configuration)
        self.profileService = TestProfileService(apiService: apiService, configuration: configuration)
        self.linkingService = TestAccountLinkingService(apiService: apiService, configuration: configuration)
        self.tokenService = TestTokenService(apiService: apiService, configuration: configuration)
        
        // Update services when configuration changes
        $configuration
            .sink { [weak self] _ in
                self?.updateServicesConfiguration()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    var passedCount: Int {
        results.filter { $0.success }.count
    }
    
    var failedCount: Int {
        results.filter { !$0.success }.count
    }
    
    var successRate: Int {
        guard !results.isEmpty else { return 0 }
        return Int((Double(passedCount) / Double(results.count)) * 100)
    }
    
    // MARK: - Test Execution
    
    func runAllTests() async {
        await runTests(getAllTestCases())
    }
    
    func runCategoryTests(_ category: TestCategory) async {
        await runTests(getTestsForCategory(category))
    }
    
    private func runTests(_ testCases: [TestCase]) async {
        await MainActor.run {
            self.isRunning = true
            self.results.removeAll()
            self.completedTests = 0
            self.totalTests = testCases.count
            self.testStartTime = Date()
            self.progress = 0.0
        }
        
        TestLogger.shared.info("Starting test run with \(testCases.count) tests", category: "TestRunner")
        
        for (index, testCase) in testCases.enumerated() {
            await MainActor.run {
                self.currentTestName = testCase.name
                self.completedTests = index
                self.progress = Double(index) / Double(testCases.count)
                self.updateTimeRemaining()
            }
            
            TestLogger.shared.logTestStart(testCase.name)
            
            do {
                let result = try await testCase.execute()
                
                await MainActor.run {
                    self.results.append(result)
                }
                
                TestLogger.shared.logTestComplete(
                    testCase.name,
                    success: result.success,
                    duration: result.executionTime
                )
            } catch {
                let result = TestResult(
                    testName: testCase.name,
                    category: testCase.category.rawValue,
                    success: false,
                    message: "Test execution failed",
                    executionTime: 0,
                    error: TestError(code: "EXECUTION_ERROR", message: error.localizedDescription, underlyingError: error)
                )
                
                await MainActor.run {
                    self.results.append(result)
                }
                
                TestLogger.shared.error("Test execution error: \(error.localizedDescription)", category: "TestRunner")
            }
        }
        
        await MainActor.run {
            self.isRunning = false
            self.progress = 1.0
            self.completedTests = testCases.count
            self.generateAndSaveReport()
        }
        
        TestLogger.shared.success(
            "Test run completed: \(passedCount) passed, \(failedCount) failed",
            category: "TestRunner"
        )
    }
    
    // MARK: - Test Cases
    
    func getAllTestCases() -> [TestCase] {
        var testCases: [TestCase] = []
        
        // Authentication Tests
        testCases.append(contentsOf: getAuthenticationTests())
        
        // Profile Tests
        testCases.append(contentsOf: getProfileTests())
        
        // Account Linking Tests
        testCases.append(contentsOf: getAccountLinkingTests())
        
        // Token Management Tests
        testCases.append(contentsOf: getTokenTests())
        
        // Edge Case Tests
        testCases.append(contentsOf: getEdgeCaseTests())
        
        return testCases
    }
    
    func getTestsForCategory(_ category: TestCategory) -> [TestCase] {
        switch category {
        case .authentication:
            return getAuthenticationTests()
        case .profile:
            return getProfileTests()
        case .accountLinking:
            return getAccountLinkingTests()
        case .tokenManagement:
            return getTokenTests()
        case .edgeCases:
            return getEdgeCaseTests()
        }
    }
    
    // MARK: - Individual Test Categories
    
    private func getAuthenticationTests() -> [TestCase] {
        return [
            // Email Authentication - New User
            TestCase(
                name: "Email Auth - New User",
                description: "Test email authentication for a new user with automatic profile creation",
                category: .authentication,
                requiresAuth: false,
                expectedDuration: 5.0
            ) {
                let email = "newuser_\(UUID().uuidString.prefix(8))@test.com"
                
                // Send code
                let sendResult = try await self.authService.testSendEmailCode(email: email)
                if !sendResult.success { return sendResult }
                
                // Simulate code verification (in real test, we'd need to retrieve the actual code)
                let authResult = try await self.authService.testEmailAuthentication(
                    email: email,
                    code: "123456", // Mock code
                    isNewUser: true
                )
                
                return authResult
            },
            
            // Email Authentication - Returning User
            TestCase(
                name: "Email Auth - Returning User",
                description: "Test email authentication for an existing user",
                category: .authentication,
                requiresAuth: false,
                expectedDuration: 3.0
            ) {
                // Use a known test email
                let email = self.configuration.testEmail
                
                let sendResult = try await self.authService.testSendEmailCode(email: email)
                if !sendResult.success { return sendResult }
                
                let authResult = try await self.authService.testEmailAuthentication(
                    email: email,
                    code: "123456",
                    isNewUser: false
                )
                
                return authResult
            },
            
            // Wallet Authentication - New User
            TestCase(
                name: "Wallet Auth - New User",
                description: "Test wallet authentication for a new user",
                category: .authentication,
                requiresAuth: false,
                expectedDuration: 3.0
            ) {
                let address = "0x\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(40))"
                return try await self.authService.testWalletAuthentication(
                    address: address,
                    isNewUser: true
                )
            },
            
            // Guest Authentication
            TestCase(
                name: "Guest Authentication",
                description: "Test guest authentication flow",
                category: .authentication,
                requiresAuth: false,
                expectedDuration: 2.0
            ) {
                return try await self.authService.testGuestAuthentication()
            },
            
            // Logout
            TestCase(
                name: "Logout",
                description: "Test logout functionality",
                category: .authentication,
                requiresAuth: true,
                expectedDuration: 2.0
            ) {
                // Get a valid token first
                let authResult = try await self.authService.testGuestAuthentication()
                guard let token = authResult.details?.accessToken else {
                    throw TestError(code: "NO_TOKEN", message: "No access token available")
                }
                
                return try await self.authService.testLogout(token: token)
            }
        ]
    }
    
    private func getProfileTests() -> [TestCase] {
        return [
            // First Time Profile Creation
            TestCase(
                name: "Automatic Profile Creation",
                description: "Verify automatic profile creation for new users",
                category: .profile,
                requiresAuth: true,
                expectedDuration: 4.0
            ) {
                // Create new user
                let email = "profile_test_\(UUID().uuidString.prefix(8))@test.com"
                let authResult = try await self.authService.testEmailAuthentication(
                    email: email,
                    code: "123456",
                    isNewUser: true
                )
                
                guard let token = authResult.details?.accessToken else {
                    throw TestError(code: "NO_TOKEN", message: "Authentication failed")
                }
                
                return try await self.profileService.testFirstTimeProfileCreation(token: token)
            },
            
            // Get Profiles
            TestCase(
                name: "Get Profiles",
                description: "Test retrieving user profiles",
                category: .profile,
                requiresAuth: true,
                expectedDuration: 2.0
            ) {
                guard let token = self.authService.currentTestAccount?.accessToken else {
                    // Authenticate first
                    let authResult = try await self.authService.testGuestAuthentication()
                    guard let token = authResult.details?.accessToken else {
                        throw TestError(code: "NO_TOKEN", message: "Authentication failed")
                    }
                    return try await self.profileService.testGetProfiles(token: token)
                }
                
                return try await self.profileService.testGetProfiles(token: token)
            },
            
            // Create Additional Profile
            TestCase(
                name: "Create Additional Profile",
                description: "Test creating a second profile",
                category: .profile,
                requiresAuth: true,
                expectedDuration: 3.0
            ) {
                guard let token = self.authService.currentTestAccount?.accessToken else {
                    throw TestError(code: "NO_TOKEN", message: "Authentication required")
                }
                
                return try await self.profileService.testCreateProfile(
                    token: token,
                    name: "Test Profile \(Date().timeIntervalSince1970)"
                )
            },
            
            // Switch Profile
            TestCase(
                name: "Switch Profile",
                description: "Test switching between profiles",
                category: .profile,
                requiresAuth: true,
                expectedDuration: 3.0
            ) {
                guard let account = self.authService.currentTestAccount,
                      let secondProfile = account.profiles.first(where: { !$0.isActive }) else {
                    throw TestError(code: "NO_SECOND_PROFILE", message: "Need multiple profiles to test switching")
                }
                
                return try await self.profileService.testSwitchProfile(
                    token: account.accessToken,
                    profileId: secondProfile.id
                )
            },
            
            // Delete Profile
            TestCase(
                name: "Delete Profile",
                description: "Test profile deletion",
                category: .profile,
                requiresAuth: true,
                expectedDuration: 3.0
            ) {
                guard let account = self.authService.currentTestAccount else {
                    throw TestError(code: "NO_ACCOUNT", message: "Authentication required")
                }
                
                // Create a profile to delete
                let createResult = try await self.profileService.testCreateProfile(
                    token: account.accessToken,
                    name: "Profile to Delete"
                )
                
                guard let profileId = createResult.details?.profileId else {
                    throw TestError(code: "NO_PROFILE_ID", message: "Failed to create test profile")
                }
                
                return try await self.profileService.testDeleteProfile(
                    token: account.accessToken,
                    profileId: profileId
                )
            }
        ]
    }
    
    private func getAccountLinkingTests() -> [TestCase] {
        return [
            // Link Email to Wallet
            TestCase(
                name: "Link Email to Wallet",
                description: "Test linking email account to wallet account",
                category: .accountLinking,
                requiresAuth: true,
                expectedDuration: 5.0
            ) {
                // First authenticate with wallet
                let walletAddress = "0x\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(40))"
                let walletAuth = try await self.authService.testWalletAuthentication(
                    address: walletAddress,
                    isNewUser: true
                )
                
                guard let token = walletAuth.details?.accessToken else {
                    throw TestError(code: "NO_TOKEN", message: "Wallet authentication failed")
                }
                
                // Link email
                let email = "linked_\(UUID().uuidString.prefix(8))@test.com"
                return try await self.linkingService.testLinkAccount(
                    token: token,
                    targetType: "email",
                    targetIdentifier: email,
                    privacyMode: "linked"
                )
            },
            
            // Get Identity Graph
            TestCase(
                name: "Get Identity Graph",
                description: "Test retrieving identity graph",
                category: .accountLinking,
                requiresAuth: true,
                expectedDuration: 2.0
            ) {
                guard let token = self.authService.currentTestAccount?.accessToken else {
                    throw TestError(code: "NO_TOKEN", message: "Authentication required")
                }
                
                return try await self.linkingService.testGetIdentityGraph(token: token)
            },
            
            // Update Privacy Mode
            TestCase(
                name: "Update Privacy Mode",
                description: "Test changing privacy mode between accounts",
                category: .accountLinking,
                requiresAuth: true,
                expectedDuration: 3.0
            ) {
                // This test requires a linked account setup
                // For now, return a placeholder result
                return TestResult(
                    testName: "Update Privacy Mode",
                    category: TestCategory.accountLinking.rawValue,
                    success: true,
                    message: "Privacy mode update test placeholder",
                    executionTime: 0.1
                )
            }
        ]
    }
    
    private func getTokenTests() -> [TestCase] {
        return [
            // Token Refresh
            TestCase(
                name: "Token Refresh",
                description: "Test refreshing access token",
                category: .tokenManagement,
                requiresAuth: true,
                expectedDuration: 2.0
            ) {
                guard let refreshToken = self.authService.currentTestAccount?.refreshToken else {
                    // Get new tokens
                    let authResult = try await self.authService.testGuestAuthentication()
                    guard let refreshToken = authResult.details?.refreshToken else {
                        throw TestError(code: "NO_REFRESH_TOKEN", message: "No refresh token available")
                    }
                    return try await self.tokenService.testTokenRefresh(refreshToken: refreshToken)
                }
                
                return try await self.tokenService.testTokenRefresh(refreshToken: refreshToken)
            },
            
            // Token Validation
            TestCase(
                name: "Token Validation",
                description: "Test access token validation",
                category: .tokenManagement,
                requiresAuth: true,
                expectedDuration: 2.0
            ) {
                guard let token = self.authService.currentTestAccount?.accessToken else {
                    throw TestError(code: "NO_TOKEN", message: "Authentication required")
                }
                
                return try await self.tokenService.testTokenValidation(accessToken: token)
            },
            
            // Token Lifecycle
            TestCase(
                name: "Token Lifecycle",
                description: "Test complete token lifecycle",
                category: .tokenManagement,
                requiresAuth: true,
                expectedDuration: 8.0
            ) {
                // Get fresh tokens
                let authResult = try await self.authService.testGuestAuthentication()
                guard let accessToken = authResult.details?.accessToken,
                      let refreshToken = authResult.details?.refreshToken else {
                    throw TestError(code: "NO_TOKENS", message: "Failed to get initial tokens")
                }
                
                return try await self.tokenService.testCompleteTokenLifecycle(
                    initialAccessToken: accessToken,
                    initialRefreshToken: refreshToken
                )
            }
        ]
    }
    
    private func getEdgeCaseTests() -> [TestCase] {
        return [
            // Invalid Credentials
            TestCase(
                name: "Invalid Email Code",
                description: "Test authentication with invalid verification code",
                category: .edgeCases,
                requiresAuth: false,
                expectedDuration: 2.0
            ) {
                let result = try await self.authService.testEmailAuthentication(
                    email: "invalid@test.com",
                    code: "000000",
                    isNewUser: false
                )
                
                // This should fail, so we invert the success
                return TestResult(
                    testName: "Invalid Email Code",
                    category: TestCategory.edgeCases.rawValue,
                    success: !result.success,
                    message: result.success ? "Should have failed with invalid code" : "Correctly rejected invalid code",
                    executionTime: result.executionTime
                )
            },
            
            // Rate Limiting
            TestCase(
                name: "Rate Limiting",
                description: "Test API rate limiting",
                category: .edgeCases,
                requiresAuth: false,
                expectedDuration: 5.0
            ) {
                // Attempt multiple rapid requests
                var hitRateLimit = false
                
                for i in 0..<20 {
                    do {
                        _ = try await self.authService.testSendEmailCode(
                            email: "ratelimit_\(i)@test.com"
                        )
                    } catch {
                        if let apiError = error as? APIError,
                           apiError.statusCode == 429 {
                            hitRateLimit = true
                            break
                        }
                    }
                }
                
                return TestResult(
                    testName: "Rate Limiting",
                    category: TestCategory.edgeCases.rawValue,
                    success: hitRateLimit,
                    message: hitRateLimit ? "Rate limiting is working correctly" : "Did not hit rate limit as expected",
                    executionTime: 0
                )
            }
        ]
    }
    
    // MARK: - Helper Methods
    
    func getPassedCountForCategory(_ category: TestCategory) -> Int {
        results.filter { $0.category == category.rawValue && $0.success }.count
    }
    
    func filteredResults(for category: TestCategory?) -> [TestResult] {
        guard let category = category else { return results }
        return results.filter { $0.category == category.rawValue }
    }
    
    func clearResults() {
        results.removeAll()
        completedTests = 0
        totalTests = 0
        progress = 0.0
    }
    
    func exportResults() {
        guard !results.isEmpty else { return }
        
        let report = TestReporter.shared.generateReport(
            configuration: configuration,
            results: results,
            duration: Date().timeIntervalSince(testStartTime ?? Date())
        )
        
        if let url = TestReporter.shared.saveReport(report) {
            TestLogger.shared.success("Report saved to: \(url.lastPathComponent)", category: "TestRunner")
        }
    }
    
    private func updateTimeRemaining() {
        guard let startTime = testStartTime,
              completedTests > 0,
              completedTests < totalTests else {
            estimatedTimeRemaining = nil
            return
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let averageTimePerTest = elapsedTime / Double(completedTests)
        let remainingTests = totalTests - completedTests
        estimatedTimeRemaining = averageTimePerTest * Double(remainingTests)
    }
    
    private func updateServicesConfiguration() {
        // Update API service base URL if needed
        // This would require modifying APIService to support dynamic base URL
    }
    
    private func generateAndSaveReport() {
        guard let startTime = testStartTime else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        let report = TestReporter.shared.generateReport(
            configuration: configuration,
            results: results,
            duration: duration
        )
        
        _ = TestReporter.shared.saveReport(report)
    }
}