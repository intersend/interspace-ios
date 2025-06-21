import Foundation

// MARK: - Test Profile Service
class TestProfileService: ObservableObject {
    private let apiService: APIService
    private let configuration: TestConfiguration
    
    init(apiService: APIService, configuration: TestConfiguration) {
        self.apiService = apiService
        self.configuration = configuration
    }
    
    // MARK: - Get Profiles Test
    
    func testGetProfiles(token: String) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        details.accessToken = token
        
        do {
            let endpoint = "/api/\(configuration.apiVersion)/profiles"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "GET"
            
            let data = try await apiService.request(
                endpoint: endpoint,
                method: .get,
                headers: ["Authorization": "Bearer \(token)"]
            )
            
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let profiles = response["data"] as? [[String: Any]] ?? response["profiles"] as? [[String: Any]] {
                
                let profileCount = profiles.count
                let hasActiveProfile = profiles.contains { $0["isActive"] as? Bool ?? false }
                let allHaveWallets = profiles.allSatisfy { $0["sessionWalletAddress"] != nil }
                
                let success = profileCount > 0 && hasActiveProfile && allHaveWallets
                
                return TestResult(
                    testName: "Get Profiles",
                    category: TestCategory.profile.rawValue,
                    success: success,
                    message: "Retrieved \(profileCount) profile(s)",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details
                )
            } else {
                throw TestError(code: "PARSE_ERROR", message: "Failed to parse profiles response")
            }
        } catch {
            return TestResult(
                testName: "Get Profiles",
                category: TestCategory.profile.rawValue,
                success: false,
                message: "Failed to retrieve profiles",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "GET_PROFILES_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Create Profile Test
    
    func testCreateProfile(token: String, name: String) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        details.accessToken = token
        
        do {
            let endpoint = "/api/\(configuration.apiVersion)/profiles"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "POST"
            
            let params: [String: Any] = [
                "name": name,
                "isDevelopmentWallet": true
            ]
            
            let data = try await apiService.request(
                endpoint: endpoint,
                method: .post,
                parameters: params,
                headers: ["Authorization": "Bearer \(token)"]
            )
            
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let profileData = response["data"] as? [String: Any] ?? response["profile"] as? [String: Any] {
                
                details.profileId = profileData["id"] as? String
                let hasWallet = profileData["sessionWalletAddress"] != nil
                let correctName = profileData["name"] as? String == name
                
                let success = details.profileId != nil && hasWallet && correctName
                
                return TestResult(
                    testName: "Create Profile",
                    category: TestCategory.profile.rawValue,
                    success: success,
                    message: success ? "Successfully created profile '\(name)'" : "Profile creation validation failed",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details
                )
            } else {
                throw TestError(code: "PARSE_ERROR", message: "Failed to parse create profile response")
            }
        } catch {
            return TestResult(
                testName: "Create Profile",
                category: TestCategory.profile.rawValue,
                success: false,
                message: "Failed to create profile",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "CREATE_PROFILE_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Switch Profile Test
    
    func testSwitchProfile(token: String, profileId: String) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        details.accessToken = token
        details.profileId = profileId
        
        do {
            let endpoint = "/api/\(configuration.apiVersion)/auth/switch-profile/\(profileId)"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "POST"
            
            let data = try await apiService.request(
                endpoint: endpoint,
                method: .post,
                headers: ["Authorization": "Bearer \(token)"]
            )
            
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let activeProfile = response["activeProfile"] as? [String: Any] {
                
                let isCorrectProfile = activeProfile["id"] as? String == profileId
                let success = response["success"] as? Bool ?? false && isCorrectProfile
                
                return TestResult(
                    testName: "Switch Profile",
                    category: TestCategory.profile.rawValue,
                    success: success,
                    message: success ? "Successfully switched to profile" : "Profile switch validation failed",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details
                )
            } else {
                throw TestError(code: "PARSE_ERROR", message: "Failed to parse switch profile response")
            }
        } catch {
            return TestResult(
                testName: "Switch Profile",
                category: TestCategory.profile.rawValue,
                success: false,
                message: "Failed to switch profile",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "SWITCH_PROFILE_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Update Profile Test
    
    func testUpdateProfile(token: String, profileId: String, newName: String) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        details.accessToken = token
        details.profileId = profileId
        
        do {
            let endpoint = "/api/\(configuration.apiVersion)/profiles/\(profileId)"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "PUT"
            
            let params: [String: Any] = ["name": newName]
            
            let data = try await apiService.request(
                endpoint: endpoint,
                method: .put,
                parameters: params,
                headers: ["Authorization": "Bearer \(token)"]
            )
            
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let profileData = response["data"] as? [String: Any] ?? response["profile"] as? [String: Any] {
                
                let updatedName = profileData["name"] as? String
                let success = updatedName == newName
                
                return TestResult(
                    testName: "Update Profile",
                    category: TestCategory.profile.rawValue,
                    success: success,
                    message: success ? "Successfully updated profile name to '\(newName)'" : "Profile update validation failed",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details
                )
            } else {
                throw TestError(code: "PARSE_ERROR", message: "Failed to parse update profile response")
            }
        } catch {
            return TestResult(
                testName: "Update Profile",
                category: TestCategory.profile.rawValue,
                success: false,
                message: "Failed to update profile",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "UPDATE_PROFILE_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - Delete Profile Test
    
    func testDeleteProfile(token: String, profileId: String) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        details.accessToken = token
        details.profileId = profileId
        
        do {
            // First check how many profiles exist
            let profilesData = try await apiService.request(
                endpoint: "/api/\(configuration.apiVersion)/profiles",
                method: .get,
                headers: ["Authorization": "Bearer \(token)"]
            )
            
            var profileCount = 0
            if let profilesResponse = try? JSONSerialization.jsonObject(with: profilesData) as? [String: Any],
               let profiles = profilesResponse["data"] as? [[String: Any]] ?? profilesResponse["profiles"] as? [[String: Any]] {
                profileCount = profiles.count
            }
            
            // Attempt to delete
            let endpoint = "/api/\(configuration.apiVersion)/profiles/\(profileId)"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "DELETE"
            
            do {
                let data = try await apiService.request(
                    endpoint: endpoint,
                    method: .delete,
                    headers: ["Authorization": "Bearer \(token)"]
                )
                
                if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let success = response["success"] as? Bool ?? false
                    
                    return TestResult(
                        testName: "Delete Profile",
                        category: TestCategory.profile.rawValue,
                        success: success,
                        message: success ? "Successfully deleted profile" : "Profile deletion failed",
                        executionTime: Date().timeIntervalSince(startTime),
                        details: details
                    )
                } else {
                    throw TestError(code: "PARSE_ERROR", message: "Failed to parse delete response")
                }
            } catch {
                // Check if it's because it's the last profile
                if profileCount == 1 {
                    return TestResult(
                        testName: "Delete Profile",
                        category: TestCategory.profile.rawValue,
                        success: true,
                        message: "Correctly prevented deletion of last profile",
                        executionTime: Date().timeIntervalSince(startTime),
                        details: details
                    )
                } else {
                    throw error
                }
            }
        } catch {
            return TestResult(
                testName: "Delete Profile",
                category: TestCategory.profile.rawValue,
                success: false,
                message: "Failed to delete profile",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "DELETE_PROFILE_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
    
    // MARK: - First Time Profile Creation Test
    
    func testFirstTimeProfileCreation(token: String) async throws -> TestResult {
        let startTime = Date()
        var details = TestDetails()
        details.accessToken = token
        
        do {
            // Get profiles to verify automatic creation
            let endpoint = "/api/\(configuration.apiVersion)/profiles"
            details.requestURL = configuration.baseURL + endpoint
            details.requestMethod = "GET"
            
            let data = try await apiService.request(
                endpoint: endpoint,
                method: .get,
                headers: ["Authorization": "Bearer \(token)"]
            )
            
            if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let profiles = response["data"] as? [[String: Any]] ?? response["profiles"] as? [[String: Any]] {
                
                let hasMySmartprofile = profiles.contains { profile in
                    (profile["name"] as? String) == "My Smartprofile"
                }
                
                let profileCount = profiles.count
                let success = profileCount == 1 && hasMySmartprofile
                
                return TestResult(
                    testName: "First Time Profile Creation",
                    category: TestCategory.profile.rawValue,
                    success: success,
                    message: success ? "Automatic profile creation verified" : "Automatic profile creation failed",
                    executionTime: Date().timeIntervalSince(startTime),
                    details: details
                )
            } else {
                throw TestError(code: "PARSE_ERROR", message: "Failed to parse profiles response")
            }
        } catch {
            return TestResult(
                testName: "First Time Profile Creation",
                category: TestCategory.profile.rawValue,
                success: false,
                message: "Failed to verify automatic profile creation",
                executionTime: Date().timeIntervalSince(startTime),
                details: details,
                error: TestError(code: "AUTO_PROFILE_FAILED", message: error.localizedDescription, underlyingError: error)
            )
        }
    }
}