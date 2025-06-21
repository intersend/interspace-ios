import Foundation

// MARK: - Test Account Linking Service
class TestAccountLinkingService: ObservableObject {
    private let apiService: APIService
    private let configuration: TestConfiguration
    
    init(apiService: APIService, configuration: TestConfiguration) {
        self.apiService = apiService
        self.configuration = configuration
    }
    
    // MARK: - Link Account Test
    
    func testLinkAccount(
        token: String,
        targetType: String,
        targetIdentifier: String,
        privacyMode: String = "linked"
    ) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        details.accessToken = token
        
        do {
            let endpoint = "/api/\(configuration.apiVersion)/auth/link-accounts"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "POST"
            
            let params: [String: Any] = [
                "targetType": targetType,
                "targetIdentifier": targetIdentifier,
                "privacyMode": privacyMode
            ]
            
            // Add provider for social accounts
            var finalParams = params
            if targetType == "social" {
                finalParams["targetProvider"] = "google" // or "apple"
            }
            
            let data = try await apiService.request(
                endpoint: endpoint,
                method: .post,
                parameters: finalParams,
                headers: ["Authorization": "Bearer \(token)"]
            )
            
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = response["success"] as? Bool ?? false
                let linkedAccount = response["linkedAccount"] as? [String: Any]
                let link = response["link"] as? [String: Any]
                
                let hasLinkedAccount = linkedAccount != nil
                let hasCorrectType = linkedAccount?["type"] as? String == targetType
                let hasCorrectPrivacy = link?["privacyMode"] as? String == privacyMode
                
                let validationSuccess = success && hasLinkedAccount && hasCorrectType && hasCorrectPrivacy
                
                return TestResult(
                    testName: "Link Account - \(targetType)",
                    category: TestCategory.accountLinking.rawValue,
                    success: validationSuccess,
                    message: validationSuccess ? "Successfully linked \(targetType) account" : "Account linking validation failed",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details
                )
            } else {
                throw TestError(code: "PARSE_ERROR", message: "Failed to parse link response")
            }
        } catch {
            // Check for specific error cases
            if let apiError = error as? APIError,
               apiError.statusCode == 409 {
                // Account already linked
                return TestResult(
                    testName: "Link Account - \(targetType)",
                    category: TestCategory.accountLinking.rawValue,
                    success: false,
                    message: "Account already linked",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details,
                    error: TestError(code: "ALREADY_LINKED", message: "Account is already linked")
                )
            }
            
            return TestResult(
                testName: "Link Account - \(targetType)",
                category: TestCategory.accountLinking.rawValue,
                success: false,
                message: "Failed to link account",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "LINK_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Get Identity Graph Test
    
    func testGetIdentityGraph(token: String) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        details.accessToken = token
        
        do {
            let endpoint = "/api/\(configuration.apiVersion)/auth/identity-graph"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "GET"
            
            let data = try await apiService.request(
                endpoint: endpoint,
                method: .get,
                headers: ["Authorization": "Bearer \(token)"]
            )
            
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let accounts = response["accounts"] as? [[String: Any]] ?? []
                let links = response["links"] as? [[String: Any]] ?? []
                let currentAccountId = response["currentAccountId"] as? String
                
                let hasCurrentAccount = currentAccountId != nil
                let accountCount = accounts.count
                let linkCount = links.count
                
                // Validate graph consistency
                let allAccountIds = Set(accounts.compactMap { $0["id"] as? String })
                let linkedAccountIds = Set(links.flatMap { link in
                    [link["accountAId"] as? String, link["accountBId"] as? String].compactMap { $0 }
                })
                
                let graphIsConsistent = linkedAccountIds.isSubset(of: allAccountIds)
                
                let success = hasCurrentAccount && accountCount > 0 && graphIsConsistent
                
                return TestResult(
                    testName: "Get Identity Graph",
                    category: TestCategory.accountLinking.rawValue,
                    success: success,
                    message: "Retrieved identity graph with \(accountCount) accounts and \(linkCount) links",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details
                )
            } else {
                throw TestError(code: "PARSE_ERROR", message: "Failed to parse identity graph")
            }
        } catch {
            return TestResult(
                testName: "Get Identity Graph",
                category: TestCategory.accountLinking.rawValue,
                success: false,
                message: "Failed to retrieve identity graph",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "GRAPH_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Update Privacy Mode Test
    
    func testUpdatePrivacyMode(
        token: String,
        targetAccountId: String,
        newPrivacyMode: String
    ) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        details.accessToken = token
        
        do {
            let endpoint = "/api/\(configuration.apiVersion)/auth/link-privacy"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "PUT"
            
            let params: [String: Any] = [
                "targetAccountId": targetAccountId,
                "privacyMode": newPrivacyMode
            ]
            
            let data = try await apiService.request(
                endpoint: endpoint,
                method: .put,
                parameters: params,
                headers: ["Authorization": "Bearer \(token)"]
            )
            
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = response["success"] as? Bool ?? false
                let link = response["link"] as? [String: Any]
                let updatedPrivacyMode = link?["privacyMode"] as? String
                
                let validationSuccess = success && updatedPrivacyMode == newPrivacyMode
                
                return TestResult(
                    testName: "Update Privacy Mode",
                    category: TestCategory.accountLinking.rawValue,
                    success: validationSuccess,
                    message: validationSuccess ? "Successfully updated privacy mode to '\(newPrivacyMode)'" : "Privacy mode update validation failed",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details
                )
            } else {
                throw TestError(code: "PARSE_ERROR", message: "Failed to parse privacy update response")
            }
        } catch {
            return TestResult(
                testName: "Update Privacy Mode",
                category: TestCategory.accountLinking.rawValue,
                success: false,
                message: "Failed to update privacy mode",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "PRIVACY_UPDATE_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Test Account Linking Scenarios
    
    func testEmailToWalletLinking(emailToken: String, walletAddress: String) async throws -> TestResult {
        let startTime = Date()
        
        // Link wallet to email account
        let linkResult = try await testLinkAccount(
            token: emailToken,
            targetType: "wallet",
            targetIdentifier: walletAddress,
            privacyMode: "linked"
        )
        
        if !linkResult.success {
            return linkResult
        }
        
        // Verify the link by checking identity graph
        let graphResult = try await testGetIdentityGraph(token: emailToken)
        
        let overallSuccess = linkResult.success && graphResult.success
        
        return TestResult(
            testName: "Email to Wallet Linking Scenario",
            category: TestCategory.accountLinking.rawValue,
            success: overallSuccess,
            message: overallSuccess ? "Successfully linked email to wallet account" : "Email to wallet linking scenario failed",
            executionTime: Date().timeIntervalSince(startTime),
            details: linkResult.details
        )
    }
    
    func testPrivacyModeScenarios(token: String, targetAccountId: String) async throws -> TestResult {
        let startTime = Date()
        var allSuccess = true
        var messages: [String] = []
        
        // Test all privacy modes
        let privacyModes = ["linked", "partial", "isolated"]
        
        for mode in privacyModes {
            let result = try await testUpdatePrivacyMode(
                token: token,
                targetAccountId: targetAccountId,
                newPrivacyMode: mode
            )
            
            allSuccess = allSuccess && result.success
            messages.append("\(mode): \(result.success ? "✓" : "✗")")
        }
        
        return TestResult(
            testName: "Privacy Mode Scenarios",
            category: TestCategory.accountLinking.rawValue,
            success: allSuccess,
            message: "Privacy mode tests: " + messages.joined(separator: ", "),
            executionTime: Date().timeIntervalSince(startTime),
            details: nil
        )
    }
    
    // MARK: - Unlink Test (if supported)
    
    func testUnlinkAccount(token: String, targetAccountId: String) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        details.accessToken = token
        
        // Note: The V2 API might not support unlinking directly
        // This is a placeholder for when/if the functionality is added
        
        return TestResult(
            testName: "Unlink Account",
            category: TestCategory.accountLinking.rawValue,
            success: false,
            message: "Account unlinking not yet implemented in V2 API",
            executionTime: Date().timeIntervalSince(startTime),
            details: details,
            error: TestError(code: "NOT_IMPLEMENTED", message: "Feature not available")
        )
    }
}