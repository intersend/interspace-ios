import Foundation

// MARK: - UI Test Mock Data Provider

class UITestMockDataProvider {
    
    // MARK: - User Mock Data
    
    static let testUsers = [
        MockUser(
            id: "test-user-1",
            email: "test@example.com",
            profiles: [defaultProfile, tradingProfile, gamingProfile]
        ),
        MockUser(
            id: "test-user-2",
            email: "wallet@example.com",
            walletAddress: "0x742d35Cc6634C0532925a3b844Bc9e7595f6BEd4",
            profiles: [defiProfile]
        ),
        MockUser(
            id: "guest-user",
            isGuest: true,
            profiles: [guestProfile]
        )
    ]
    
    // MARK: - Profile Mock Data
    
    static let defaultProfile = MockProfile(
        id: "profile-1",
        name: "Main Profile",
        icon: "🏠",
        color: "Blue",
        accounts: [
            MockAccount(type: .email, identifier: "test@example.com"),
            MockAccount(type: .google, identifier: "google@example.com")
        ]
    )
    
    static let tradingProfile = MockProfile(
        id: "profile-2",
        name: "Trading",
        icon: "📈",
        color: "Green",
        accounts: [
            MockAccount(type: .wallet, identifier: "0x742d35Cc6634C0532925a3b844Bc9e7595f6BEd4", walletType: "MetaMask")
        ]
    )
    
    static let gamingProfile = MockProfile(
        id: "profile-3",
        name: "Gaming",
        icon: "🎮",
        color: "Purple",
        accounts: [
            MockAccount(type: .apple, identifier: "apple@example.com")
        ]
    )
    
    static let defiProfile = MockProfile(
        id: "profile-4",
        name: "DeFi Portfolio",
        icon: "💎",
        color: "Yellow",
        accounts: [
            MockAccount(type: .wallet, identifier: "0x742d35Cc6634C0532925a3b844Bc9e7595f6BEd4", walletType: "MetaMask"),
            MockAccount(type: .wallet, identifier: "0x123d35Cc6634C0532925a3b844Bc9e7595f6BEd5", walletType: "Coinbase")
        ]
    )
    
    static let guestProfile = MockProfile(
        id: "guest-profile",
        name: "Guest",
        icon: "👤",
        color: "Gray",
        accounts: []
    )
    
    // MARK: - App Mock Data
    
    static let mockApps = [
        MockApp(
            id: "app-1",
            name: "Uniswap",
            icon: "🦄",
            url: "https://app.uniswap.org",
            category: "DeFi"
        ),
        MockApp(
            id: "app-2",
            name: "OpenSea",
            icon: "⛵",
            url: "https://opensea.io",
            category: "NFT"
        ),
        MockApp(
            id: "app-3",
            name: "Aave",
            icon: "👻",
            url: "https://app.aave.com",
            category: "DeFi"
        ),
        MockApp(
            id: "app-4",
            name: "Axie Infinity",
            icon: "🎮",
            url: "https://marketplace.axieinfinity.com",
            category: "Gaming"
        )
    ]
    
    // MARK: - Transaction Mock Data
    
    static let mockTransactions = [
        MockTransaction(
            id: "tx-1",
            hash: "0x123...abc",
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f6BEd4",
            to: "0x456...def",
            value: "0.5 ETH",
            status: "Confirmed",
            timestamp: Date().addingTimeInterval(-3600)
        ),
        MockTransaction(
            id: "tx-2",
            hash: "0x789...ghi",
            from: "0x456...def",
            to: "0x742d35Cc6634C0532925a3b844Bc9e7595f6BEd4",
            value: "100 USDC",
            status: "Pending",
            timestamp: Date().addingTimeInterval(-1800)
        ),
        MockTransaction(
            id: "tx-3",
            hash: "0xabc...xyz",
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f6BEd4",
            to: "0x789...jkl",
            value: "1 NFT",
            status: "Failed",
            timestamp: Date().addingTimeInterval(-7200)
        )
    ]
    
    // MARK: - API Response Mock Data
    
    static func mockAuthResponse(for email: String) -> [String: Any] {
        return [
            "success": true,
            "message": "Verification code sent",
            "data": [
                "email": email,
                "codeExpiry": Date().addingTimeInterval(300).timeIntervalSince1970
            ]
        ]
    }
    
    static func mockVerificationResponse(success: Bool = true) -> [String: Any] {
        if success {
            return [
                "success": true,
                "data": [
                    "token": "mock-jwt-token-123",
                    "refreshToken": "mock-refresh-token-456",
                    "user": [
                        "id": "test-user-1",
                        "email": "test@example.com"
                    ]
                ]
            ]
        } else {
            return [
                "success": false,
                "error": [
                    "code": "INVALID_CODE",
                    "message": "Invalid verification code"
                ]
            ]
        }
    }
    
    static func mockWalletConnectionResponse() -> [String: Any] {
        return [
            "success": true,
            "data": [
                "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f6BEd4",
                "chainId": 1,
                "connected": true
            ]
        ]
    }
    
    static func mockProfilesResponse() -> [String: Any] {
        return [
            "success": true,
            "data": [
                "profiles": [defaultProfile.toDictionary(), tradingProfile.toDictionary(), gamingProfile.toDictionary()]
            ]
        ]
    }
}

// MARK: - Mock Data Models

struct MockUser {
    let id: String
    var email: String?
    var walletAddress: String?
    var isGuest: Bool = false
    var profiles: [MockProfile]
}

struct MockProfile {
    let id: String
    let name: String
    let icon: String
    let color: String
    var accounts: [MockAccount]
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "icon": icon,
            "color": color,
            "accounts": accounts.map { $0.toDictionary() }
        ]
    }
}

struct MockAccount {
    let type: AccountType
    let identifier: String
    var walletType: String?
    
    enum AccountType: String {
        case email = "email"
        case google = "google"
        case apple = "apple"
        case wallet = "wallet"
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "identifier": identifier
        ]
        if let walletType = walletType {
            dict["walletType"] = walletType
        }
        return dict
    }
}

struct MockApp {
    let id: String
    let name: String
    let icon: String
    let url: String
    let category: String
}

struct MockTransaction {
    let id: String
    let hash: String
    let from: String
    let to: String
    let value: String
    let status: String
    let timestamp: Date
}

// MARK: - Test Scenario Configurations

extension UITestMockDataProvider {
    
    enum TestScenario {
        case firstTimeUser
        case returningUser
        case walletUser
        case guestUser
        case multiProfile
        case offlineMode
        case serverError
        case tokenExpired
    }
    
    static func configure(app: XCUIApplication, for scenario: TestScenario) {
        switch scenario {
        case .firstTimeUser:
            app.launchArguments = ["UI-Testing", "First-Time-User"]
            app.launchEnvironment = [
                "MOCK_API": "true",
                "USER_STATE": "new"
            ]
            
        case .returningUser:
            app.launchArguments = ["UI-Testing", "Returning-User"]
            app.launchEnvironment = [
                "MOCK_API": "true",
                "USER_STATE": "authenticated",
                "USER_ID": "test-user-1"
            ]
            
        case .walletUser:
            app.launchArguments = ["UI-Testing", "Wallet-User"]
            app.launchEnvironment = [
                "MOCK_API": "true",
                "USER_STATE": "wallet",
                "WALLET_ADDRESS": "0x742d35Cc6634C0532925a3b844Bc9e7595f6BEd4"
            ]
            
        case .guestUser:
            app.launchArguments = ["UI-Testing", "Guest-User"]
            app.launchEnvironment = [
                "MOCK_API": "true",
                "USER_STATE": "guest"
            ]
            
        case .multiProfile:
            app.launchArguments = ["UI-Testing", "Multi-Profile"]
            app.launchEnvironment = [
                "MOCK_API": "true",
                "USER_STATE": "authenticated",
                "PROFILE_COUNT": "3"
            ]
            
        case .offlineMode:
            app.launchArguments = ["UI-Testing", "Offline-Mode"]
            app.launchEnvironment = [
                "MOCK_API": "true",
                "NETWORK_STATE": "offline"
            ]
            
        case .serverError:
            app.launchArguments = ["UI-Testing", "Server-Error"]
            app.launchEnvironment = [
                "MOCK_API": "true",
                "API_STATE": "error"
            ]
            
        case .tokenExpired:
            app.launchArguments = ["UI-Testing", "Token-Expired"]
            app.launchEnvironment = [
                "MOCK_API": "true",
                "TOKEN_STATE": "expired"
            ]
        }
    }
}

// MARK: - Accessibility Test Data

extension UITestMockDataProvider {
    
    static let accessibilityLabels = [
        "Connect Wallet": "Connect your cryptocurrency wallet",
        "Continue with Email": "Sign in or create account with email",
        "Continue with Google": "Sign in with Google account",
        "Continue with Apple": "Sign in with Apple ID",
        "Continue as Guest": "Browse without creating an account",
        "Profile Switcher": "Switch between profiles",
        "Add App": "Add new decentralized application",
        "Transaction History": "View your transaction history",
        "Settings": "Application settings and preferences"
    ]
    
    static let accessibilityHints = [
        "Connect Wallet": "Double tap to connect your MetaMask or other Web3 wallet",
        "Profile name": "Enter a name for your profile",
        "Verification Code": "Enter the 6-digit code sent to your email",
        "Send Token": "Double tap to send cryptocurrency tokens"
    ]
}