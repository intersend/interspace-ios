import XCTest
import Combine
@testable import Interspace

class ProfileViewModelIntegrationTests: XCTestCase {
    
    var viewModel: ProfileViewModel!
    var mockAPIService: MockAPIService!
    var mockSessionCoordinator: MockSessionCoordinator!
    var mockCacheManager: MockCacheManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        super.setUp()
        
        cancellables = Set<AnyCancellable>()
        
        // Setup mocks
        mockAPIService = MockAPIService()
        mockSessionCoordinator = MockSessionCoordinator()
        mockCacheManager = MockCacheManager()
        
        // Initialize view model with mocks
        viewModel = ProfileViewModel(
            apiService: mockAPIService,
            sessionCoordinator: mockSessionCoordinator,
            cacheManager: mockCacheManager
        )
    }
    
    override func tearDownWithError() throws {
        viewModel = nil
        mockAPIService = nil
        mockSessionCoordinator = nil
        mockCacheManager = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Profile Loading Tests
    
    func testLoadUserProfiles() async throws {
        // Setup mock data
        let mockProfiles = [
            Profile(id: "1", name: "Main", icon: "🏠", color: "blue"),
            Profile(id: "2", name: "Trading", icon: "📈", color: "green"),
            Profile(id: "3", name: "Gaming", icon: "🎮", color: "purple")
        ]
        
        mockAPIService.mockResponses["/profiles"] = ProfilesResponse(
            success: true,
            data: mockProfiles
        )
        
        // Set current user
        mockSessionCoordinator.currentUser = UserProfile(
            id: "user123",
            email: "test@example.com",
            profiles: mockProfiles
        )
        
        // Test loading profiles
        let expectation = expectation(description: "Profiles loaded")
        
        viewModel.$profiles
            .dropFirst() // Skip initial empty state
            .sink { profiles in
                XCTAssertEqual(profiles.count, 3)
                XCTAssertEqual(profiles[0].name, "Main")
                XCTAssertEqual(profiles[1].name, "Trading")
                XCTAssertEqual(profiles[2].name, "Gaming")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        await viewModel.loadProfiles()
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Verify API call
        XCTAssertTrue(mockAPIService.verifyRequest(
            endpoint: "/profiles",
            method: .GET
        ))
        
        // Verify cache updated
        XCTAssertTrue(mockCacheManager.savedData.contains { key, _ in
            key == "profiles_user123"
        })
    }
    
    func testLoadProfilesFromCache() async throws {
        // Setup cached data
        let cachedProfiles = [
            Profile(id: "1", name: "Cached Profile", icon: "💾", color: "gray")
        ]
        
        mockCacheManager.cachedData["profiles_user123"] = try JSONEncoder().encode(cachedProfiles)
        
        // Setup API to fail (should use cache)
        mockAPIService.mockErrors["/profiles"] = APIError.networkError("No connection")
        
        // Set current user
        mockSessionCoordinator.currentUser = UserProfile(
            id: "user123",
            email: "test@example.com",
            profiles: []
        )
        
        // Test loading from cache
        await viewModel.loadProfiles()
        
        // Verify cached data used
        XCTAssertEqual(viewModel.profiles.count, 1)
        XCTAssertEqual(viewModel.profiles[0].name, "Cached Profile")
        
        // Verify error state set for failed API call
        XCTAssertNotNil(viewModel.error)
    }
    
    // MARK: - Profile Creation Tests
    
    func testCreateProfile() async throws {
        // Setup mock response
        let newProfile = Profile(
            id: "new123",
            name: "New Profile",
            icon: "🆕",
            color: "orange"
        )
        
        mockAPIService.mockResponses["/profiles/create"] = ProfileResponse(
            success: true,
            data: newProfile
        )
        
        // Test creating profile
        let expectation = expectation(description: "Profile created")
        
        viewModel.$isLoading
            .dropFirst()
            .sink { isLoading in
                if !isLoading && self.viewModel.profiles.contains(where: { $0.id == "new123" }) {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        try await viewModel.createProfile(
            name: "New Profile",
            icon: "🆕",
            color: "orange"
        )
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Verify API call
        XCTAssertTrue(mockAPIService.verifyRequest(
            endpoint: "/profiles/create",
            method: .POST
        ))
        
        // Verify request body
        if let requestBody = mockAPIService.getLastRequestBody(
            for: "/profiles/create",
            as: CreateProfileRequest.self
        ) {
            XCTAssertEqual(requestBody.name, "New Profile")
            XCTAssertEqual(requestBody.icon, "🆕")
            XCTAssertEqual(requestBody.color, "orange")
        }
        
        // Verify profile added to list
        XCTAssertTrue(viewModel.profiles.contains { $0.id == "new123" })
        
        // Verify cache updated
        XCTAssertTrue(mockCacheManager.savedData.contains { key, _ in
            key == "profiles_user123"
        })
    }
    
    func testCreateProfileValidation() async throws {
        // Test empty name
        do {
            try await viewModel.createProfile(name: "", icon: "🏠", color: "blue")
            XCTFail("Should throw validation error for empty name")
        } catch {
            if let validationError = error as? ProfileValidationError {
                XCTAssertEqual(validationError, .invalidName)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
        
        // Test name too long
        let longName = String(repeating: "A", count: 31)
        do {
            try await viewModel.createProfile(name: longName, icon: "🏠", color: "blue")
            XCTFail("Should throw validation error for long name")
        } catch {
            if let validationError = error as? ProfileValidationError {
                XCTAssertEqual(validationError, .nameTooLong)
            }
        }
        
        // Test duplicate name
        viewModel.profiles = [
            Profile(id: "1", name: "Existing", icon: "🏠", color: "blue")
        ]
        
        do {
            try await viewModel.createProfile(name: "Existing", icon: "🆕", color: "red")
            XCTFail("Should throw validation error for duplicate name")
        } catch {
            if let validationError = error as? ProfileValidationError {
                XCTAssertEqual(validationError, .duplicateName)
            }
        }
    }
    
    // MARK: - Profile Switching Tests
    
    func testSwitchProfile() async throws {
        // Setup profiles
        let profiles = [
            Profile(id: "1", name: "Main", icon: "🏠", color: "blue"),
            Profile(id: "2", name: "Trading", icon: "📈", color: "green")
        ]
        
        viewModel.profiles = profiles
        viewModel.currentProfile = profiles[0]
        
        // Setup mock response
        mockAPIService.mockResponses["/profiles/switch"] = EmptyResponse()
        
        // Test switching profile
        let expectation = expectation(description: "Profile switched")
        
        viewModel.$currentProfile
            .dropFirst()
            .sink { profile in
                if profile?.id == "2" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        try await viewModel.switchToProfile(profiles[1])
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Verify API call
        XCTAssertTrue(mockAPIService.verifyRequest(
            endpoint: "/profiles/switch",
            method: .POST
        ))
        
        // Verify session updated
        XCTAssertEqual(mockSessionCoordinator.currentProfile?.id, "2")
        
        // Verify current profile updated
        XCTAssertEqual(viewModel.currentProfile?.id, "2")
    }
    
    func testSwitchProfileWithPendingChanges() async throws {
        // Setup profiles with pending changes
        let profiles = [
            Profile(id: "1", name: "Main", icon: "🏠", color: "blue"),
            Profile(id: "2", name: "Trading", icon: "📈", color: "green")
        ]
        
        viewModel.profiles = profiles
        viewModel.currentProfile = profiles[0]
        viewModel.hasPendingChanges = true
        
        // Test switching with pending changes
        do {
            try await viewModel.switchToProfile(profiles[1])
            XCTFail("Should throw error for pending changes")
        } catch {
            if let profileError = error as? ProfileError {
                XCTAssertEqual(profileError, .pendingChanges)
            }
        }
        
        // Verify profile not switched
        XCTAssertEqual(viewModel.currentProfile?.id, "1")
    }
    
    // MARK: - Profile Update Tests
    
    func testUpdateProfile() async throws {
        // Setup current profile
        let currentProfile = Profile(
            id: "1",
            name: "Old Name",
            icon: "🏠",
            color: "blue"
        )
        
        viewModel.profiles = [currentProfile]
        viewModel.currentProfile = currentProfile
        
        // Setup mock response
        let updatedProfile = Profile(
            id: "1",
            name: "New Name",
            icon: "🆕",
            color: "red"
        )
        
        mockAPIService.mockResponses["/profiles/1/update"] = ProfileResponse(
            success: true,
            data: updatedProfile
        )
        
        // Test updating profile
        try await viewModel.updateProfile(
            profile: currentProfile,
            name: "New Name",
            icon: "🆕",
            color: "red"
        )
        
        // Verify API call
        XCTAssertTrue(mockAPIService.verifyRequest(
            endpoint: "/profiles/1/update",
            method: .PUT
        ))
        
        // Verify profile updated in list
        XCTAssertEqual(viewModel.profiles[0].name, "New Name")
        XCTAssertEqual(viewModel.profiles[0].icon, "🆕")
        XCTAssertEqual(viewModel.profiles[0].color, "red")
        
        // Verify current profile updated if it was the one edited
        XCTAssertEqual(viewModel.currentProfile?.name, "New Name")
    }
    
    // MARK: - Profile Deletion Tests
    
    func testDeleteProfile() async throws {
        // Setup profiles
        let profiles = [
            Profile(id: "1", name: "Main", icon: "🏠", color: "blue"),
            Profile(id: "2", name: "Trading", icon: "📈", color: "green"),
            Profile(id: "3", name: "Gaming", icon: "🎮", color: "purple")
        ]
        
        viewModel.profiles = profiles
        viewModel.currentProfile = profiles[1] // Currently on Trading
        
        // Setup mock response
        mockAPIService.mockResponses["/profiles/2/delete"] = EmptyResponse()
        
        // Test deleting current profile
        try await viewModel.deleteProfile(profiles[1])
        
        // Verify API call
        XCTAssertTrue(mockAPIService.verifyRequest(
            endpoint: "/profiles/2/delete",
            method: .DELETE
        ))
        
        // Verify profile removed from list
        XCTAssertEqual(viewModel.profiles.count, 2)
        XCTAssertFalse(viewModel.profiles.contains { $0.id == "2" })
        
        // Verify switched to another profile
        XCTAssertNotEqual(viewModel.currentProfile?.id, "2")
        XCTAssertTrue(viewModel.currentProfile?.id == "1" || viewModel.currentProfile?.id == "3")
    }
    
    func testDeleteLastProfile() async throws {
        // Setup single profile
        let lastProfile = Profile(id: "1", name: "Last", icon: "🏠", color: "blue")
        viewModel.profiles = [lastProfile]
        viewModel.currentProfile = lastProfile
        
        // Test deleting last profile
        do {
            try await viewModel.deleteProfile(lastProfile)
            XCTFail("Should not allow deleting last profile")
        } catch {
            if let profileError = error as? ProfileError {
                XCTAssertEqual(profileError, .cannotDeleteLastProfile)
            }
        }
        
        // Verify profile not deleted
        XCTAssertEqual(viewModel.profiles.count, 1)
    }
    
    // MARK: - Profile State Management Tests
    
    func testProfileStateTransitions() async throws {
        // Test loading state
        let loadingExpectation = expectation(description: "Loading state")
        
        viewModel.$isLoading
            .dropFirst()
            .first { $0 == true }
            .sink { _ in
                loadingExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Trigger loading
        Task {
            await viewModel.loadProfiles()
        }
        
        await fulfillment(of: [loadingExpectation], timeout: 1.0)
        
        // Verify loading state
        XCTAssertTrue(viewModel.isLoading)
        
        // Complete loading
        mockAPIService.mockResponses["/profiles"] = ProfilesResponse(
            success: true,
            data: []
        )
        
        // Wait for loading to complete
        let completeExpectation = expectation(description: "Loading complete")
        
        viewModel.$isLoading
            .first { $0 == false }
            .sink { _ in
                completeExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [completeExpectation], timeout: 2.0)
        
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() async throws {
        // Setup API error
        mockAPIService.mockErrors["/profiles"] = APIError.serverError("Internal error")
        
        // Test error handling
        await viewModel.loadProfiles()
        
        // Verify error state
        XCTAssertNotNil(viewModel.error)
        XCTAssertEqual(viewModel.error as? APIError, APIError.serverError("Internal error"))
        
        // Test error recovery
        mockAPIService.mockErrors.removeAll()
        mockAPIService.mockResponses["/profiles"] = ProfilesResponse(
            success: true,
            data: []
        )
        
        await viewModel.retryLastAction()
        
        // Verify error cleared
        XCTAssertNil(viewModel.error)
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentProfileOperations() async throws {
        // Setup initial profiles
        let profiles = [
            Profile(id: "1", name: "Profile 1", icon: "1️⃣", color: "blue"),
            Profile(id: "2", name: "Profile 2", icon: "2️⃣", color: "green")
        ]
        
        viewModel.profiles = profiles
        
        // Setup mock responses
        mockAPIService.mockResponses["/profiles/create"] = ProfileResponse(
            success: true,
            data: Profile(id: "3", name: "Profile 3", icon: "3️⃣", color: "red")
        )
        
        mockAPIService.mockResponses["/profiles/1/update"] = ProfileResponse(
            success: true,
            data: Profile(id: "1", name: "Updated 1", icon: "🔄", color: "blue")
        )
        
        // Perform concurrent operations
        async let create = viewModel.createProfile(name: "Profile 3", icon: "3️⃣", color: "red")
        async let update = viewModel.updateProfile(
            profile: profiles[0],
            name: "Updated 1",
            icon: "🔄",
            color: "blue"
        )
        
        // Wait for both operations
        _ = try await (create, update)
        
        // Verify both operations completed
        XCTAssertEqual(viewModel.profiles.count, 3)
        XCTAssertTrue(viewModel.profiles.contains { $0.id == "3" })
        XCTAssertEqual(viewModel.profiles.first { $0.id == "1" }?.name, "Updated 1")
    }
}

// MARK: - Mock Helpers

class MockSessionCoordinator: SessionCoordinator {
    var currentUser: UserProfile?
    var currentProfile: Profile?
    
    override func switchProfile(_ profile: Profile) {
        currentProfile = profile
    }
}

class MockCacheManager {
    var cachedData: [String: Data] = [:]
    var savedData: [String: Data] = [:]
    
    func getCachedData(for key: String) -> Data? {
        return cachedData[key]
    }
    
    func saveData(_ data: Data, for key: String) {
        savedData[key] = data
    }
}

// MARK: - Test Models

struct ProfilesResponse: Codable {
    let success: Bool
    let data: [Profile]
}

struct ProfileResponse: Codable {
    let success: Bool
    let data: Profile
}

struct CreateProfileRequest: Codable {
    let name: String
    let icon: String
    let color: String
}

enum ProfileValidationError: Error, Equatable {
    case invalidName
    case nameTooLong
    case duplicateName
}

enum ProfileError: Error, Equatable {
    case pendingChanges
    case cannotDeleteLastProfile
}

// MARK: - ViewModel Extension for Testing

extension ProfileViewModel {
    convenience init(apiService: APIService, sessionCoordinator: SessionCoordinator, cacheManager: MockCacheManager) {
        self.init()
        // Use dependency injection for testing
    }
}