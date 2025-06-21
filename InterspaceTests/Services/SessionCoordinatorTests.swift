import XCTest
import Combine
@testable import Interspace

@MainActor
class SessionCoordinatorTests: XCTestCase {
    
    var sut: SessionCoordinator!
    var mockAuthManager: AuthenticationManager!
    var mockAPIService: MockAPIService!
    var mockKeychainManager: MockKeychainManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        await super.setUp()
        
        // Setup mocks
        mockAPIService = MockAPIService()
        mockKeychainManager = MockKeychainManager()
        cancellables = Set<AnyCancellable>()
        
        // Replace shared instances
        APIService.shared = mockAPIService
        KeychainManager.shared = mockKeychainManager
        
        // Initialize managers
        mockAuthManager = AuthenticationManager.shared
        sut = SessionCoordinator.shared
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        mockAPIService.reset()
        mockKeychainManager.reset()
        await super.tearDown()
    }
    
    // MARK: - Session State Tests
    
    func testInitialSessionStateIsLoading() {
        XCTAssertEqual(sut.sessionState, .loading)
    }
    
    func testSessionStateTransitionsToUnauthenticated() async throws {
        // Given
        mockKeychainManager.clearTokens()
        
        // When authentication check happens
        mockAuthManager.checkAuthenticationStatus()
        
        // Wait for state update
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(sut.sessionState, .unauthenticated)
        XCTAssertFalse(sut.isAuthenticated)
        XCTAssertNil(sut.currentUser)
        XCTAssertNil(sut.activeProfile)
    }
    
    func testSessionStateTransitionsToNeedsProfile() async throws {
        // Given
        let testUser = TestDataFactory.createTestUser(profilesCount: 0)
        mockAPIService.mockResponses["/users/me"] = testUser
        mockAPIService.mockResponses["/profiles"] = [SmartProfile]() // Empty profiles
        
        // When
        await sut.loadUserSession()
        
        // Then
        XCTAssertEqual(sut.sessionState, .needsProfile)
        XCTAssertNotNil(sut.currentUser)
        XCTAssertNil(sut.activeProfile)
    }
    
    func testSessionStateTransitionsToAuthenticated() async throws {
        // Given
        let testUser = TestDataFactory.createTestUser()
        let testProfile = TestDataFactory.createTestProfile(isActive: true)
        
        mockAPIService.mockResponses["/users/me"] = testUser
        mockAPIService.mockResponses["/profiles"] = [testProfile]
        
        // When
        await sut.loadUserSession()
        
        // Then
        XCTAssertEqual(sut.sessionState, .authenticated)
        XCTAssertNotNil(sut.currentUser)
        XCTAssertNotNil(sut.activeProfile)
        XCTAssertEqual(sut.activeProfile?.id, testProfile.id)
    }
    
    func testGuestUserSessionHandling() async throws {
        // Given
        let guestUser = TestDataFactory.createTestUser(isGuest: true, authStrategies: ["guest"])
        mockAuthManager.currentUser = guestUser
        
        // When
        await sut.loadUserSession()
        
        // Then
        XCTAssertEqual(sut.sessionState, .authenticated)
        XCTAssertNotNil(sut.currentUser)
        XCTAssertTrue(sut.currentUser?.isGuest ?? false)
        XCTAssertNil(sut.activeProfile)
        
        // Verify no API calls for guest users
        XCTAssertFalse(mockAPIService.verifyRequest(endpoint: "/users/me", method: .GET))
        XCTAssertFalse(mockAPIService.verifyRequest(endpoint: "/profiles", method: .GET))
    }
    
    // MARK: - Profile Management Tests
    
    func testCreateInitialProfile() async throws {
        // Given
        let profileName = "My First Profile"
        let newProfile = TestDataFactory.createTestProfile(name: profileName)
        
        mockAPIService.mockResponses["/profiles"] = newProfile
        mockAPIService.mockResponses["/profiles/\(newProfile.id)/activate"] = ["success": true]
        
        // When
        await sut.createInitialProfile(name: profileName)
        
        // Then
        XCTAssertEqual(sut.sessionState, .authenticated)
        XCTAssertNotNil(sut.activeProfile)
        XCTAssertEqual(sut.activeProfile?.name, profileName)
        
        // Verify API calls
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/profiles", method: .POST))
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/profiles/\(newProfile.id)/activate", method: .POST))
    }
    
    func testProfileSwitching() async throws {
        // Given
        let currentProfile = TestDataFactory.createTestProfile(id: "profile-1", name: "Profile 1", isActive: true)
        let targetProfile = TestDataFactory.createTestProfile(id: "profile-2", name: "Profile 2", isActive: false)
        
        sut.activeProfile = currentProfile
        sut.sessionState = .authenticated
        
        mockAPIService.mockResponses["/profiles/\(targetProfile.id)/activate"] = ["success": true]
        
        // Create expectation for profile change notification
        let notificationExpectation = expectation(description: "Profile change notification")
        var receivedProfile: SmartProfile?
        
        NotificationCenter.default.addObserver(
            forName: .profileDidChange,
            object: nil,
            queue: .main
        ) { notification in
            receivedProfile = notification.userInfo?["profile"] as? SmartProfile
            notificationExpectation.fulfill()
        }
        
        // When
        await sut.switchProfile(targetProfile)
        
        // Then
        await fulfillment(of: [notificationExpectation], timeout: 2.0)
        
        XCTAssertEqual(sut.activeProfile?.id, targetProfile.id)
        XCTAssertEqual(receivedProfile?.id, targetProfile.id)
        XCTAssertFalse(sut.isSwitchingProfile)
        XCTAssertEqual(sut.profileSwitchProgress, 0.0)
        
        // Verify API call
        XCTAssertTrue(mockAPIService.verifyRequest(endpoint: "/profiles/\(targetProfile.id)/activate", method: .POST))
    }
    
    func testProfileSwitchingWithSameProfile() async throws {
        // Given
        let currentProfile = TestDataFactory.createTestProfile()
        sut.activeProfile = currentProfile
        
        // When
        await sut.switchProfile(currentProfile)
        
        // Then - No API calls should be made
        XCTAssertEqual(mockAPIService.requestHistory.count, 0)
        XCTAssertEqual(sut.activeProfile?.id, currentProfile.id)
    }
    
    func testProfileSwitchingError() async throws {
        // Given
        let currentProfile = TestDataFactory.createTestProfile(id: "profile-1")
        let targetProfile = TestDataFactory.createTestProfile(id: "profile-2")
        
        sut.activeProfile = currentProfile
        sut.sessionState = .authenticated
        
        mockAPIService.mockErrors["/profiles/\(targetProfile.id)/activate"] = APIError.networkError("Connection failed")
        
        // When
        await sut.switchProfile(targetProfile)
        
        // Then
        XCTAssertEqual(sut.activeProfile?.id, currentProfile.id) // Should remain on current profile
        XCTAssertNotNil(sut.error)
        XCTAssertTrue(sut.showError)
        
        if case .profileSwitchFailed(let message) = sut.error {
            XCTAssertTrue(message.contains("Connection failed"))
        } else {
            XCTFail("Wrong error type")
        }
    }
    
    // MARK: - Session Security Tests
    
    func testSessionLockOnBackground() async throws {
        // Given
        sut.sessionState = .authenticated
        
        // When app goes to background
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        // Wait for timer (using shorter time for testing)
        try await Task.sleep(nanoseconds: 61_000_000_000) // 61 seconds
        
        // Then
        XCTAssertEqual(sut.sessionState, .locked)
    }
    
    func testBiometricVerification() async throws {
        // Given
        sut.sessionState = .locked
        
        // When
        await sut.verifyBiometricAccess()
        
        // Then
        XCTAssertEqual(sut.sessionState, .authenticated)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorDismissal() {
        // Given
        sut.error = .networkError("Test error")
        sut.showError = true
        
        // When
        sut.dismissError()
        
        // Then
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.showError)
    }
    
    // MARK: - Logout Tests
    
    func testLogout() async throws {
        // Given
        sut.sessionState = .authenticated
        sut.currentUser = TestDataFactory.createTestUser()
        sut.activeProfile = TestDataFactory.createTestProfile()
        
        mockAPIService.mockResponses["/auth/logout"] = EmptyResponse()
        
        // Create expectation for session end notification
        let notificationExpectation = expectation(description: "Session end notification")
        NotificationCenter.default.addObserver(
            forName: .sessionDidEnd,
            object: nil,
            queue: .main
        ) { _ in
            notificationExpectation.fulfill()
        }
        
        // When
        await sut.logout()
        
        // Then
        await fulfillment(of: [notificationExpectation], timeout: 2.0)
        
        XCTAssertEqual(sut.sessionState, .unauthenticated)
        XCTAssertNil(sut.currentUser)
        XCTAssertNil(sut.activeProfile)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isSwitchingProfile)
    }
    
    // MARK: - Computed Properties Tests
    
    func testComputedProperties() {
        // Test needsOnboarding
        sut.sessionState = .needsProfile
        XCTAssertTrue(sut.needsOnboarding)
        
        sut.sessionState = .authenticated
        XCTAssertFalse(sut.needsOnboarding)
        
        // Test isLoading
        sut.sessionState = .loading
        XCTAssertTrue(sut.isLoading)
        
        sut.sessionState = .authenticated
        XCTAssertFalse(sut.isLoading)
        
        // Test canProceed
        sut.sessionState = .authenticated
        sut.activeProfile = TestDataFactory.createTestProfile()
        XCTAssertTrue(sut.canProceed)
        
        sut.activeProfile = nil
        XCTAssertFalse(sut.canProceed)
        
        // Test isLocked
        sut.sessionState = .locked
        XCTAssertTrue(sut.isLocked)
        
        sut.sessionState = .authenticated
        XCTAssertFalse(sut.isLocked)
    }
}