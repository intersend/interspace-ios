import Foundation
import Combine

// MARK: - Test Auth Service
class TestAuthService: ObservableObject {
    private let apiService: APIService
    private let configuration: TestConfiguration
    @Published var currentTestAccount: TestAccount?
    
    init(apiService: APIService, configuration: TestConfiguration) {
        self.apiService = apiService
        self.configuration = configuration
    }
    
    // MARK: - Email Authentication Tests
    
    func testSendEmailCode(email: String) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        
        do {
            let endpoint = "/api/\(configuration.apiVersion)/auth/send-email-code"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "POST"
            
            let response = try await apiService.sendEmailVerificationCode(email: email)
            
            details.responseStatusCode = 200
            let executionTime = Date().timeIntervalSince(startTime)
            
            return TestResult(
                testName: "Send Email Verification Code",
                category: TestCategory.authentication.rawValue,
                success: true,
                message: "Successfully sent verification code to \(email)",
                executionTime: executionTime,
                details: details
            )
        } catch {
            details.responseStatusCode = (error as? APIError)?.statusCode
            return TestResult(
                testName: "Send Email Verification Code",
                category: TestCategory.authentication.rawValue,
                success: false,
                message: "Failed to send verification code",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "SEND_CODE_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    func testEmailAuthentication(email: String, code: String, isNewUser: Bool) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        
        do {
            let endpoint = "/api/\(configuration.apiVersion)/auth/authenticate"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "POST"
            
            let params: [String: Any] = [
                "strategy": "email",
                "email": email,
                "verificationCode": code
            ]
            
            let data = try await apiService.request(
                endpoint: endpoint,
                method: .post,
                parameters: params
            )
            
            // Parse response
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                details.accountId = response["account"] as? [String: Any]?["id"] as? String
                details.profileId = response["activeProfile"] as? [String: Any]?["id"] as? String
                details.accessToken = response["tokens"] as? [String: Any]?["accessToken"] as? String
                details.refreshToken = response["tokens"] as? [String: Any]?["refreshToken"] as? String
                details.sessionId = response["sessionId"] as? String
                
                let actualIsNewUser = response["isNewUser"] as? Bool ?? false
                let profiles = response["profiles"] as? [[String: Any]] ?? []
                
                // Validate response
                let success = actualIsNewUser == isNewUser && 
                            !profiles.isEmpty && 
                            details.accessToken != nil
                
                if success {
                    // Store test account
                    currentTestAccount = TestAccount(
                        accountId: details.accountId ?? "",
                        type: "email",
                        identifier: email,
                        accessToken: details.accessToken ?? "",
                        refreshToken: details.refreshToken ?? "",
                        profiles: profiles.compactMap { dict in
                            guard let id = dict["id"] as? String,
                                  let name = dict["name"] as? String else { return nil }
                            return TestProfile(id: id, name: name, isActive: dict["isActive"] as? Bool ?? false)
                        }
                    )
                }
                
                details.responseStatusCode = 200
                let executionTime = Date().timeIntervalSince(startTime)
                
                return TestResult(
                    testName: "Email Authentication - \(isNewUser ? "New" : "Returning") User",
                    category: TestCategory.authentication.rawValue,
                    success: success,
                    message: success ? "Successfully authenticated with email" : "Authentication succeeded but validation failed",
                    executionTime: executionTime,
                    details: details
                )
            } else {
                throw TestError(code: "PARSE_ERROR", message: "Failed to parse response")
            }
        } catch {
            details.responseStatusCode = (error as? APIError)?.statusCode
            return TestResult(
                testName: "Email Authentication - \(isNewUser ? "New" : "Returning") User",
                category: TestCategory.authentication.rawValue,
                success: false,
                message: "Authentication failed",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "AUTH_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Wallet Authentication Tests
    
    func testWalletAuthentication(address: String, isNewUser: Bool) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        
        do {
            // Generate test message and signature
            let message = "Sign in to Interspace\n\nTimestamp: \(Date().timeIntervalSince1970)"
            let signature = try generateTestSignature(for: message, address: address)
            
            let endpoint = "/api/\(configuration.apiVersion)/auth/authenticate"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "POST"
            
            let params: [String: Any] = [
                "strategy": "wallet",
                "walletAddress": address,
                "message": message,
                "signature": signature,
                "walletType": "metamask"
            ]
            
            let data = try await apiService.request(
                endpoint: endpoint,
                method: .post,
                parameters: params
            )
            
            // Parse and validate response
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                details.accountId = response["account"] as? [String: Any]?["id"] as? String
                details.accessToken = response["tokens"] as? [String: Any]?["accessToken"] as? String
                details.refreshToken = response["tokens"] as? [String: Any]?["refreshToken"] as? String
                
                let actualIsNewUser = response["isNewUser"] as? Bool ?? false
                let success = actualIsNewUser == isNewUser && details.accessToken != nil
                
                return TestResult(
                    testName: "Wallet Authentication - \(isNewUser ? "New" : "Returning") User",
                    category: TestCategory.authentication.rawValue,
                    success: success,
                    message: success ? "Successfully authenticated with wallet" : "Authentication succeeded but validation failed",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details
                )
            } else {
                throw TestError(code: "PARSE_ERROR", message: "Failed to parse response")
            }
        } catch {
            return TestResult(
                testName: "Wallet Authentication - \(isNewUser ? "New" : "Returning") User",
                category: TestCategory.authentication.rawValue,
                success: false,
                message: "Authentication failed",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "WALLET_AUTH_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Guest Authentication Test
    
    func testGuestAuthentication() async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        
        do {
            let endpoint = "/api/\(configuration.apiVersion)/auth/authenticate"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "POST"
            
            let params: [String: Any] = [
                "strategy": "guest",
                "deviceId": UUID().uuidString
            ]
            
            let data = try await apiService.request(
                endpoint: endpoint,
                method: .post,
                parameters: params
            )
            
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                details.accountId = response["account"] as? [String: Any]?["id"] as? String
                details.accessToken = response["tokens"] as? [String: Any]?["accessToken"] as? String
                
                let isNewUser = response["isNewUser"] as? Bool ?? false
                let accountType = response["account"] as? [String: Any]?["type"] as? String
                
                let success = isNewUser && accountType == "guest" && details.accessToken != nil
                
                return TestResult(
                    testName: "Guest Authentication",
                    category: TestCategory.authentication.rawValue,
                    success: success,
                    message: success ? "Successfully authenticated as guest" : "Guest authentication validation failed",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details
                )
            } else {
                throw TestError(code: "PARSE_ERROR", message: "Failed to parse response")
            }
        } catch {
            return TestResult(
                testName: "Guest Authentication",
                category: TestCategory.authentication.rawValue,
                success: false,
                message: "Guest authentication failed",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "GUEST_AUTH_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Logout Test
    
    func testLogout(token: String) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        
        do {
            let endpoint = "/api/\(configuration.apiVersion)/auth/logout"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "POST"
            details.accessToken = token
            
            let data = try await apiService.request(
                endpoint: endpoint,
                method: .post,
                headers: ["Authorization": "Bearer \(token)"]
            )
            
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = response["success"] as? Bool ?? false
                
                if success {
                    currentTestAccount = nil
                }
                
                return TestResult(
                    testName: "Logout",
                    category: TestCategory.authentication.rawValue,
                    success: success,
                    message: success ? "Successfully logged out" : "Logout failed",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details
                )
            } else {
                throw TestError(code: "PARSE_ERROR", message: "Failed to parse response")
            }
        } catch {
            return TestResult(
                testName: "Logout",
                category: TestCategory.authentication.rawValue,
                success: false,
                message: "Logout request failed",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "LOGOUT_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateTestSignature(for message: String, address: String) throws -> String {
        // In a real implementation, this would use actual wallet signing
        // For testing, we'll use a mock signature
        return "0x" + Data(message.utf8).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Test Models
struct TestAccount {
    let accountId: String
    let type: String
    let identifier: String
    let accessToken: String
    let refreshToken: String
    let profiles: [TestProfile]
}

struct TestProfile {
    let id: String
    let name: String
    let isActive: Bool
}