import Foundation

// MARK: - Test Case Types
enum TestCategory: String, CaseIterable {
    case authentication = "Authentication"
    case profile = "Profile Management"
    case accountLinking = "Account Linking"
    case tokenManagement = "Token Management"
    case edgeCases = "Edge Cases"
    
    var icon: String {
        switch self {
        case .authentication: return "lock.shield"
        case .profile: return "person.crop.circle"
        case .accountLinking: return "link"
        case .tokenManagement: return "key"
        case .edgeCases: return "exclamationmark.triangle"
        }
    }
}

enum TestState: String {
    case notStarted = "Not Started"
    case running = "Running"
    case passed = "Passed"
    case failed = "Failed"
    case skipped = "Skipped"
    
    var color: String {
        switch self {
        case .notStarted: return "gray"
        case .running: return "blue"
        case .passed: return "green"
        case .failed: return "red"
        case .skipped: return "orange"
        }
    }
}

// MARK: - Test Case Model
struct TestCase: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let category: TestCategory
    let requiresAuth: Bool
    let expectedDuration: TimeInterval
    var state: TestState = .notStarted
    var result: TestResult?
    var executionTime: TimeInterval?
    
    // Test execution closure
    let execute: () async throws -> TestResult
}

// MARK: - Test Configuration
struct TestConfiguration {
    var useProductionAPI: Bool = false
    var apiVersion: String = "v2"
    var baseURL: String {
        useProductionAPI ? "https://api.interspace.fi" : "http://localhost:3000"
    }
    var enableDetailedLogging: Bool = true
    var autoRunOnLaunch: Bool = false
    var testTimeout: TimeInterval = 30.0
    
    // Test credentials
    var testEmail: String = "test@interspace.test"
    var testWalletAddress: String = "0x742d35Cc6634C0532925a3b844Bc9e7595f2222"
    var testWalletPrivateKey: String = "" // Will be generated
    var testGoogleIdToken: String = ""
    var testAppleIdToken: String = ""
}

// MARK: - Test Suite
struct TestSuite {
    let name: String
    let description: String
    let testCases: [TestCase]
    var totalPassed: Int {
        testCases.filter { $0.state == .passed }.count
    }
    var totalFailed: Int {
        testCases.filter { $0.state == .failed }.count
    }
    var totalSkipped: Int {
        testCases.filter { $0.state == .skipped }.count
    }
    var isComplete: Bool {
        testCases.allSatisfy { $0.state != .notStarted && $0.state != .running }
    }
}