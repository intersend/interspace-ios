import XCTest
@testable import Interspace

// MARK: - V2 API XCTest Suite
final class V2APITests: XCTestCase {
    
    private var testSuite: V2APITestSuite!
    private let timeout: TimeInterval = 30.0
    
    override func setUpWithError() throws {
        super.setUpWithError()
        
        // Configure test environment
        let config = TestHubConfiguration(
            environment: ProcessInfo.processInfo.environment["TEST_ENV"] ?? "dev",
            category: nil,
            outputFormat: "console",
            verbose: true
        )
        
        testSuite = V2APITestSuite(configuration: config)
    }
    
    override func tearDownWithError() throws {
        testSuite = nil
        super.tearDownWithError()
    }
    
    // MARK: - Authentication Tests
    
    func testEmailAuthNewUser() async throws {
        let test = testSuite.getTestsForCategory("auth").first { $0.name == "Email Auth - New User" }
        XCTAssertNotNil(test)
        
        try await test?.execute()
    }
    
    func testEmailAuthReturningUser() async throws {
        let test = testSuite.getTestsForCategory("auth").first { $0.name == "Email Auth - Returning User" }
        XCTAssertNotNil(test)
        
        try await test?.execute()
    }
    
    func testWalletAuthNewUser() async throws {
        let test = testSuite.getTestsForCategory("auth").first { $0.name == "Wallet Auth - New User" }
        XCTAssertNotNil(test)
        
        try await test?.execute()
    }
    
    func testGuestAuthentication() async throws {
        let test = testSuite.getTestsForCategory("auth").first { $0.name == "Guest Authentication" }
        XCTAssertNotNil(test)
        
        try await test?.execute()
    }
    
    func testLogout() async throws {
        let test = testSuite.getTestsForCategory("auth").first { $0.name == "Logout" }
        XCTAssertNotNil(test)
        
        try await test?.execute()
    }
    
    // MARK: - Profile Tests
    
    func testAutomaticProfileCreation() async throws {
        let test = testSuite.getTestsForCategory("profile").first { $0.name == "Automatic Profile Creation" }
        XCTAssertNotNil(test)
        
        try await test?.execute()
    }
    
    func testGetProfiles() async throws {
        let test = testSuite.getTestsForCategory("profile").first { $0.name == "Get Profiles" }
        XCTAssertNotNil(test)
        
        try await test?.execute()
    }
    
    func testCreateAdditionalProfile() async throws {
        let test = testSuite.getTestsForCategory("profile").first { $0.name == "Create Additional Profile" }
        XCTAssertNotNil(test)
        
        try await test?.execute()
    }
    
    // MARK: - Account Linking Tests
    
    func testLinkEmailToWallet() async throws {
        let test = testSuite.getTestsForCategory("linking").first { $0.name == "Link Email to Wallet" }
        XCTAssertNotNil(test)
        
        try await test?.execute()
    }
    
    func testGetIdentityGraph() async throws {
        let test = testSuite.getTestsForCategory("linking").first { $0.name == "Get Identity Graph" }
        XCTAssertNotNil(test)
        
        try await test?.execute()
    }
    
    // MARK: - Token Management Tests
    
    func testTokenRefresh() async throws {
        let test = testSuite.getTestsForCategory("token").first { $0.name == "Token Refresh" }
        XCTAssertNotNil(test)
        
        try await test?.execute()
    }
    
    func testTokenValidation() async throws {
        let test = testSuite.getTestsForCategory("token").first { $0.name == "Token Validation" }
        XCTAssertNotNil(test)
        
        try await test?.execute()
    }
    
    // MARK: - Edge Case Tests
    
    func testInvalidEmailCode() async throws {
        let test = testSuite.getTestsForCategory("edge").first { $0.name == "Invalid Email Code" }
        XCTAssertNotNil(test)
        
        try await test?.execute()
    }
    
    func testRateLimiting() async throws {
        let test = testSuite.getTestsForCategory("edge").first { $0.name == "Rate Limiting" }
        XCTAssertNotNil(test)
        
        try await test?.execute()
    }
    
    // MARK: - Test Suite Execution
    
    func testFullSuite() async throws {
        let expectation = XCTestExpectation(description: "Full test suite completion")
        var passedCount = 0
        var failedCount = 0
        
        let allTests = testSuite.getAllTests()
        
        for test in allTests {
            do {
                print("🧪 Running: \(test.name)")
                try await test.execute()
                passedCount += 1
                print("  ✅ Passed")
            } catch {
                failedCount += 1
                print("  ❌ Failed: \(error.localizedDescription)")
                XCTFail("\(test.name) failed: \(error.localizedDescription)")
            }
        }
        
        print("\n📊 Test Summary")
        print("================")
        print("Total: \(allTests.count)")
        print("Passed: \(passedCount)")
        print("Failed: \(failedCount)")
        print("Success Rate: \(String(format: "%.1f%%", Double(passedCount) / Double(allTests.count) * 100))")
        
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 300) // 5 minute timeout for full suite
    }
}

// MARK: - Test Helpers

extension V2APITests {
    
    /// Run a specific test category
    func runCategory(_ category: String) async throws {
        let tests = testSuite.getTestsForCategory(category)
        
        for test in tests {
            try await test.execute()
        }
    }
    
    /// Run tests matching a pattern
    func runTestsMatching(_ pattern: String) async throws {
        let allTests = testSuite.getAllTests()
        let matchingTests = allTests.filter { $0.name.contains(pattern) }
        
        for test in matchingTests {
            try await test.execute()
        }
    }
}