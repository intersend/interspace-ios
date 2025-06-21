import Foundation

// MARK: - Test Scenario
struct TestScenario {
    let name: String
    let description: String
    let steps: [TestStep]
    let expectedOutcome: ExpectedOutcome
    let cleanupRequired: Bool
}

// MARK: - Test Step
struct TestStep {
    let order: Int
    let description: String
    let action: TestAction
    let validation: TestValidation?
}

// MARK: - Test Actions
enum TestAction {
    // Authentication
    case sendEmailCode(email: String)
    case verifyEmailCode(email: String, code: String)
    case authenticateWallet(address: String, signature: String, message: String)
    case authenticateSocial(provider: String, idToken: String)
    case authenticateGuest
    
    // Profile
    case createProfile(name: String)
    case switchProfile(profileId: String)
    case updateProfile(profileId: String, name: String)
    case deleteProfile(profileId: String)
    case getProfiles
    
    // Account Linking
    case linkAccount(type: String, identifier: String, privacyMode: String)
    case unlinkAccount(accountId: String)
    case updatePrivacyMode(accountId: String, mode: String)
    case getIdentityGraph
    
    // Token Management
    case refreshToken(refreshToken: String)
    case logout
    case validateToken(accessToken: String)
    
    // Utils
    case wait(seconds: TimeInterval)
    case clearStorage
    case setTestData(key: String, value: Any)
}

// MARK: - Test Validation
struct TestValidation {
    let field: ValidationField
    let condition: ValidationCondition
    let expectedValue: Any?
    
    enum ValidationField {
        case statusCode
        case responseBody(keyPath: String)
        case headerValue(key: String)
        case tokenPresent
        case profileCount
        case accountLinked
        case errorCode
        case executionTime
    }
    
    enum ValidationCondition {
        case equals
        case notEquals
        case contains
        case greaterThan
        case lessThan
        case exists
        case notExists
    }
}

// MARK: - Expected Outcome
struct ExpectedOutcome {
    let success: Bool
    let statusCode: Int?
    let responseContains: [String]?
    let responseExcludes: [String]?
    let stateChanges: [StateChange]?
}

struct StateChange {
    let entity: String // "account", "profile", "token"
    let field: String
    let from: Any?
    let to: Any
}

// MARK: - Predefined Test Scenarios
extension TestScenario {
    // Authentication Scenarios
    static let emailAuthNewUser = TestScenario(
        name: "Email Authentication - New User",
        description: "Tests email authentication flow for a new user with automatic profile creation",
        steps: [
            TestStep(
                order: 1,
                description: "Send verification code to test email",
                action: .sendEmailCode(email: "newuser@test.com"),
                validation: TestValidation(
                    field: .statusCode,
                    condition: .equals,
                    expectedValue: 200
                )
            ),
            TestStep(
                order: 2,
                description: "Verify email with code",
                action: .verifyEmailCode(email: "newuser@test.com", code: "123456"),
                validation: TestValidation(
                    field: .responseBody(keyPath: "isNewUser"),
                    condition: .equals,
                    expectedValue: true
                )
            ),
            TestStep(
                order: 3,
                description: "Validate automatic profile creation",
                action: .getProfiles,
                validation: TestValidation(
                    field: .profileCount,
                    condition: .equals,
                    expectedValue: 1
                )
            )
        ],
        expectedOutcome: ExpectedOutcome(
            success: true,
            statusCode: 200,
            responseContains: ["My Smartprofile", "account", "tokens"],
            responseExcludes: nil,
            stateChanges: [
                StateChange(entity: "account", field: "verified", from: nil, to: true),
                StateChange(entity: "profile", field: "count", from: 0, to: 1)
            ]
        ),
        cleanupRequired: true
    )
    
    static let walletAuthReturningUser = TestScenario(
        name: "Wallet Authentication - Returning User",
        description: "Tests wallet authentication for existing user with profiles",
        steps: [
            TestStep(
                order: 1,
                description: "Authenticate with wallet signature",
                action: .authenticateWallet(
                    address: "0x742d35Cc6634C0532925a3b844Bc9e7595f2222",
                    signature: "0x...",
                    message: "Sign in to Interspace"
                ),
                validation: TestValidation(
                    field: .responseBody(keyPath: "isNewUser"),
                    condition: .equals,
                    expectedValue: false
                )
            ),
            TestStep(
                order: 2,
                description: "Verify existing profiles returned",
                action: .getProfiles,
                validation: TestValidation(
                    field: .profileCount,
                    condition: .greaterThan,
                    expectedValue: 0
                )
            )
        ],
        expectedOutcome: ExpectedOutcome(
            success: true,
            statusCode: 200,
            responseContains: ["account", "profiles", "tokens"],
            responseExcludes: ["error"],
            stateChanges: nil
        ),
        cleanupRequired: false
    )
    
    static let accountLinkingScenario = TestScenario(
        name: "Account Linking - Email to Wallet",
        description: "Tests linking email account to existing wallet account",
        steps: [
            TestStep(
                order: 1,
                description: "Authenticate with wallet",
                action: .authenticateWallet(
                    address: "0x742d35Cc6634C0532925a3b844Bc9e7595f2222",
                    signature: "0x...",
                    message: "Sign in"
                ),
                validation: TestValidation(
                    field: .tokenPresent,
                    condition: .exists,
                    expectedValue: nil
                )
            ),
            TestStep(
                order: 2,
                description: "Link email account",
                action: .linkAccount(
                    type: "email",
                    identifier: "linked@test.com",
                    privacyMode: "linked"
                ),
                validation: TestValidation(
                    field: .statusCode,
                    condition: .equals,
                    expectedValue: 200
                )
            ),
            TestStep(
                order: 3,
                description: "Verify identity graph",
                action: .getIdentityGraph,
                validation: TestValidation(
                    field: .responseBody(keyPath: "accounts.count"),
                    condition: .equals,
                    expectedValue: 2
                )
            )
        ],
        expectedOutcome: ExpectedOutcome(
            success: true,
            statusCode: 200,
            responseContains: ["linkedAccount", "accessibleProfiles"],
            responseExcludes: ["error"],
            stateChanges: [
                StateChange(entity: "account", field: "linkedCount", from: 1, to: 2)
            ]
        ),
        cleanupRequired: true
    )
}