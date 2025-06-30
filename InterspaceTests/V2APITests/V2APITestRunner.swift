import Foundation
@testable import Interspace

// MARK: - V2 API Test Runner

class V2APITestRunner {
    
    private let apiService: APIService
    private var testResults: [TestResult] = []
    
    init() {
        // Use production API for testing
        let config = APIConfiguration(
            baseURL: "https://9e68-184-147-176-114.ngrok-free.app/api/v2",
            timeout: 30,
            retryCount: 3
        )
        self.apiService = APIService(configuration: config)
    }
    
    // MARK: - Public Methods
    
    func runAllTests() async -> TestSummary {
        print("🚀 Starting V2 API Tests")
        print("========================")
        
        testResults = []
        
        // Run test suites
        await runAuthenticationTests()
        await runProfileTests()
        await runTokenTests()
        await runEdgeCaseTests()
        
        // Generate summary
        let passed = testResults.filter { $0.success }.count
        let failed = testResults.filter { !$0.success }.count
        let total = testResults.count
        
        return TestSummary(
            totalTests: total,
            passed: passed,
            failed: failed,
            results: testResults
        )
    }
    
    // MARK: - Authentication Tests
    
    private func runAuthenticationTests() async {
        print("\n📁 AUTHENTICATION TESTS")
        print("----------------------")
        
        // Test 1: Guest Authentication
        await runTest("Guest Authentication") { [weak self] in
            guard let self = self else { return false }
            
            do {
                let response = try await self.apiService.request(
                    endpoint: "auth/authenticate",
                    method: .POST,
                    parameters: ["strategy": "guest"]
                )
                
                let json = try JSONSerialization.jsonObject(with: response) as? [String: Any]
                guard let success = json?["success"] as? Bool,
                      success == true,
                      let tokens = json?["tokens"] as? [String: Any],
                      let accessToken = tokens["accessToken"] as? String else {
                    print("   ❌ Failed to parse response")
                    return false
                }
                
                // Store token for subsequent tests
                self.apiService.setAuthToken(accessToken)
                print("   ✅ Guest auth successful")
                return true
            } catch {
                print("   ❌ Error: \(error.localizedDescription)")
                return false
            }
        }
        
        // Test 2: Email Code Request
        await runTest("Email Code Request") { [weak self] in
            guard let self = self else { return false }
            
            do {
                let response = try await self.apiService.request(
                    endpoint: "auth/send-email-code",
                    method: .POST,
                    parameters: ["email": "test@example.com"]
                )
                
                let json = try JSONSerialization.jsonObject(with: response) as? [String: Any]
                guard let success = json?["success"] as? Bool, success == true else {
                    print("   ❌ Failed to send email code")
                    return false
                }
                
                print("   ✅ Email code sent successfully")
                return true
            } catch {
                print("   ❌ Error: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    // MARK: - Profile Tests
    
    private func runProfileTests() async {
        print("\n📁 PROFILE TESTS")
        print("---------------")
        
        // Test 1: Get Profiles
        await runTest("Get Profiles") { [weak self] in
            guard let self = self else { return false }
            
            do {
                let response = try await self.apiService.request(
                    endpoint: "profiles",
                    method: .GET
                )
                
                let json = try JSONSerialization.jsonObject(with: response) as? [String: Any]
                guard let success = json?["success"] as? Bool,
                      success == true,
                      let profiles = json?["data"] as? [[String: Any]] else {
                    print("   ❌ Failed to parse profiles")
                    return false
                }
                
                print("   ✅ Found \(profiles.count) profile(s)")
                
                // Check for "My Smartprofile"
                let hasMySmartprofile = profiles.contains { profile in
                    (profile["name"] as? String) == "My Smartprofile"
                }
                
                if !hasMySmartprofile {
                    print("   ⚠️  'My Smartprofile' not found")
                    return false
                }
                
                return true
            } catch {
                print("   ❌ Error: \(error.localizedDescription)")
                return false
            }
        }
        
        // Test 2: Create Profile
        await runTest("Create Additional Profile") { [weak self] in
            guard let self = self else { return false }
            
            do {
                let profileName = "Test Profile \(Int.random(in: 1000...9999))"
                let response = try await self.apiService.request(
                    endpoint: "profiles",
                    method: .POST,
                    parameters: ["name": profileName]
                )
                
                let json = try JSONSerialization.jsonObject(with: response) as? [String: Any]
                guard let success = json?["success"] as? Bool,
                      success == true,
                      let profile = json?["data"] as? [String: Any],
                      let createdName = profile["name"] as? String,
                      createdName == profileName else {
                    print("   ❌ Failed to create profile")
                    return false
                }
                
                print("   ✅ Profile created: \(profileName)")
                return true
            } catch {
                print("   ❌ Error: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    // MARK: - Token Tests
    
    private func runTokenTests() async {
        print("\n📁 TOKEN TESTS")
        print("-------------")
        
        // Test 1: Token Refresh
        await runTest("Token Refresh") { [weak self] in
            guard let self = self else { return false }
            
            do {
                let response = try await self.apiService.request(
                    endpoint: "auth/refresh",
                    method: .POST
                )
                
                let json = try JSONSerialization.jsonObject(with: response) as? [String: Any]
                guard let success = json?["success"] as? Bool,
                      success == true,
                      let tokens = json?["tokens"] as? [String: Any],
                      let newAccessToken = tokens["accessToken"] as? String else {
                    print("   ❌ Failed to refresh token")
                    return false
                }
                
                // Update token
                self.apiService.setAuthToken(newAccessToken)
                print("   ✅ Token refreshed successfully")
                return true
            } catch {
                print("   ❌ Error: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    private func runEdgeCaseTests() async {
        print("\n📁 EDGE CASE TESTS")
        print("-----------------")
        
        // Test 1: Invalid Email Code
        await runTest("Invalid Email Code") { [weak self] in
            guard let self = self else { return false }
            
            do {
                _ = try await self.apiService.request(
                    endpoint: "auth/authenticate",
                    method: .POST,
                    parameters: [
                        "strategy": "email",
                        "email": "test@example.com",
                        "code": "INVALID"
                    ]
                )
                
                print("   ❌ Invalid code was accepted (should have failed)")
                return false
            } catch {
                // Expected to fail
                print("   ✅ Invalid code properly rejected")
                return true
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func runTest(_ name: String, test: () async -> Bool) async {
        print("🧪 \(name)...", terminator: "")
        let start = Date()
        
        let success = await test()
        let duration = Date().timeIntervalSince(start)
        
        let result = TestResult(
            name: name,
            success: success,
            duration: duration,
            timestamp: Date()
        )
        
        testResults.append(result)
        
        if !success {
            print(" [FAILED in \(String(format: "%.2fs", duration))]")
        } else {
            print(" [PASSED in \(String(format: "%.2fs", duration))]")
        }
    }
}

// MARK: - Test Models

struct TestResult {
    let name: String
    let success: Bool
    let duration: TimeInterval
    let timestamp: Date
}

struct TestSummary {
    let totalTests: Int
    let passed: Int
    let failed: Int
    let results: [TestResult]
    
    var successRate: Double {
        return totalTests > 0 ? Double(passed) / Double(totalTests) * 100 : 0
    }
    
    func printSummary() {
        print("\n" + String(repeating: "=", count: 50))
        print("📊 TEST SUMMARY")
        print(String(repeating: "=", count: 50))
        print("Total Tests: \(totalTests)")
        print("Passed: \(passed) ✅")
        print("Failed: \(failed) ❌")
        print("Success Rate: \(String(format: "%.1f%%", successRate))")
        print("")
        
        if failed > 0 {
            print("Failed Tests:")
            for result in results where !result.success {
                print("  - \(result.name)")
            }
        }
    }
}