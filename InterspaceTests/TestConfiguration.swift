import Foundation
import UIKit
@testable import Interspace

/// Test configuration and environment setup
struct TestConfiguration {
    
    /// Configure test environment
    static func setUp() {
        // Disable animations for faster tests
        UIView.setAnimationsEnabled(false)
        
        // Set test environment
        ProcessInfo.processInfo.environment["IS_TESTING"] = "true"
        
        // Configure UserDefaults for testing
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        
        // Set up mock API base URL
        if let testURL = URL(string: "http://localhost:8080/api/v1") {
            // In real implementation, we'd inject this into APIService
        }
    }
    
    /// Reset test environment
    static func tearDown() {
        // Re-enable animations
        UIView.setAnimationsEnabled(true)
        
        // Clear test data
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        
        // Clear keychain (in test environment only)
        KeychainManager.shared.clearTokens()
    }
}

/// Test launch arguments handler
struct TestLaunchArgumentsHandler {
    
    static func handle(_ arguments: [String]) {
        if arguments.contains("UI-Testing") {
            // Configure for UI testing
            configureMockServices()
        }
        
        if arguments.contains("Authenticated-User") {
            // Set up authenticated user state
            setupAuthenticatedUser()
        }
        
        if arguments.contains("Reset-State") {
            // Reset all app state
            resetAppState()
        }
        
        if arguments.contains("Performance-Testing") {
            // Configure for performance testing
            configurePerformanceTesting()
        }
    }
    
    private static func configureMockServices() {
        // Replace real services with mocks
        // This would be done through dependency injection in real app
    }
    
    private static func setupAuthenticatedUser() {
        // Create mock authenticated user state
        let mockTokens = (
            access: "mock-access-token",
            refresh: "mock-refresh-token",
            expiresIn: 3600
        )
        
        try? KeychainManager.shared.saveTokens(
            access: mockTokens.access,
            refresh: mockTokens.refresh,
            expiresIn: mockTokens.expiresIn
        )
    }
    
    private static func resetAppState() {
        // Clear all stored data
        KeychainManager.shared.clearTokens()
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    }
    
    private static func configurePerformanceTesting() {
        // Disable non-essential features for performance testing
        // Enable performance monitoring
    }
}

/// Mock data provider for UI tests
struct UITestMockDataProvider {
    
    static func mockUser() -> User {
        return User(
            id: "ui-test-user",
            email: "uitest@example.com",
            walletAddress: "0xUITest1234567890",
            isGuest: false,
            authStrategies: ["email", "wallet"],
            profilesCount: 3,
            linkedAccountsCount: 2,
            activeDevicesCount: 1,
            socialAccounts: [],
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    static func mockProfiles() -> [SmartProfile] {
        return [
            SmartProfile(
                id: "profile-1",
                userId: "ui-test-user",
                name: "Trading",
                icon: "📈",
                color: "#FF5733",
                isActive: true,
                linkedAccountsCount: 2,
                appsCount: 5,
                linkedAccounts: [],
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            ),
            SmartProfile(
                id: "profile-2",
                userId: "ui-test-user",
                name: "Gaming",
                icon: "🎮",
                color: "#33FF57",
                isActive: false,
                linkedAccountsCount: 1,
                appsCount: 3,
                linkedAccounts: [],
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            ),
            SmartProfile(
                id: "profile-3",
                userId: "ui-test-user",
                name: "DeFi",
                icon: "🏦",
                color: "#3357FF",
                isActive: false,
                linkedAccountsCount: 3,
                appsCount: 8,
                linkedAccounts: [],
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
        ]
    }
    
    static func mockAuthResponse() -> AuthenticationResponse {
        return AuthenticationResponse(
            success: true,
            data: AuthenticationData(
                accessToken: "ui-test-access-token",
                refreshToken: "ui-test-refresh-token",
                expiresIn: 3600,
                walletProfileInfo: nil
            ),
            message: "Authentication successful"
        )
    }
}