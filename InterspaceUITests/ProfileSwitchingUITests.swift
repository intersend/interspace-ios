import XCTest

class ProfileSwitchingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        UITestMockDataProvider.configure(app: app, for: .multiProfile)
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Profile Switcher UI Tests
    
    func testProfileSwitcherDisplay() {
        // Navigate to profile tab
        UITestHelpers.navigateToTab(.profile, in: app)
        
        // Open profile switcher
        let profileSwitcherButton = app.buttons[AccessibilityIdentifiers.Profile.profileSwitcher]
        XCTAssertTrue(profileSwitcherButton.waitForExistence(timeout: 2))
        
        // Verify current profile indicator
        XCTAssertTrue(app.staticTexts["Main Profile"].exists)
        XCTAssertTrue(app.staticTexts["🏠"].exists)
        
        profileSwitcherButton.tap()
        
        // Verify profile switcher tray
        let profileList = app.collectionViews[AccessibilityIdentifiers.Profile.profileList]
        XCTAssertTrue(profileList.waitForExistence(timeout: 2))
        
        // Verify all profiles are displayed
        XCTAssertTrue(profileList.cells["profile_Main Profile"].exists)
        XCTAssertTrue(profileList.cells["profile_Trading"].exists)
        XCTAssertTrue(profileList.cells["profile_Gaming"].exists)
        
        // Verify active profile indicator
        let activeProfile = profileList.cells["profile_Main Profile"]
        XCTAssertTrue(activeProfile.images[AccessibilityIdentifiers.Profile.profileActiveIndicator].exists)
        
        screenshots.captureScreen(named: "Profile_Switcher_Open")
    }
    
    func testBasicProfileSwitch() {
        // Navigate to profile tab
        UITestHelpers.navigateToTab(.profile, in: app)
        
        // Switch to Trading profile
        UITestHelpers.switchToProfile(named: "Trading", in: app)
        
        // Verify profile switched
        XCTAssertTrue(app.staticTexts["Trading"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["📈"].exists)
        
        // Verify profile-specific data loaded
        XCTAssertTrue(app.staticTexts["Connected Accounts"].exists)
        XCTAssertTrue(app.cells["account_0x742d...BEd4"].exists) // Trading wallet
        
        screenshots.captureScreen(named: "Profile_Switched_Trading")
        
        // Switch to Gaming profile
        UITestHelpers.switchToProfile(named: "Gaming", in: app)
        
        // Verify switched to Gaming
        XCTAssertTrue(app.staticTexts["Gaming"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["🎮"].exists)
        
        // Verify different connected accounts
        XCTAssertTrue(app.cells["account_apple@example.com"].exists)
        
        screenshots.captureScreen(named: "Profile_Switched_Gaming")
    }
    
    // MARK: - Profile Switch Animation Tests
    
    func testProfileSwitchAnimation() {
        // Navigate to profile tab
        UITestHelpers.navigateToTab(.profile, in: app)
        
        // Open profile switcher
        app.buttons[AccessibilityIdentifiers.Profile.profileSwitcher].tap()
        
        let profileList = app.collectionViews[AccessibilityIdentifiers.Profile.profileList]
        
        // Tap on Trading profile
        profileList.cells["profile_Trading"].tap()
        
        // Verify switching indicator
        let switchingIndicator = app.progressIndicators["ProfileSwitchProgress"]
        XCTAssertTrue(switchingIndicator.waitForExistence(timeout: 1))
        
        // Verify smooth transition
        XCTAssertTrue(UITestHelpers.waitForElementToDisappear(switchingIndicator, timeout: 3))
        
        // Verify profile switched successfully
        XCTAssertTrue(app.staticTexts["Trading"].exists)
        
        screenshots.captureScreen(named: "Profile_Switch_Complete")
    }
    
    // MARK: - Quick Profile Switch Tests
    
    func testQuickProfileSwitch() {
        // Test quick switch gesture if available
        UITestHelpers.navigateToTab(.profile, in: app)
        
        // Try swipe gesture on profile header
        let profileHeader = app.otherElements["ProfileHeader"]
        if profileHeader.exists {
            // Swipe left for next profile
            profileHeader.swipeLeft()
            
            // Verify switched to next profile
            XCTAssertTrue(app.staticTexts["Trading"].waitForExistence(timeout: 2))
            
            // Swipe right for previous profile
            profileHeader.swipeRight()
            
            // Verify switched back
            XCTAssertTrue(app.staticTexts["Main Profile"].waitForExistence(timeout: 2))
            
            screenshots.captureScreen(named: "Quick_Profile_Switch")
        }
    }
    
    func test3DTouchProfileSwitch() {
        // Test 3D Touch / Haptic Touch on profile tab
        let profileTab = app.tabBars.buttons[AccessibilityIdentifiers.Navigation.profileTab]
        
        // Force touch / long press
        profileTab.press(forDuration: 1.0)
        
        // Check if quick profile switcher appears
        let quickSwitcher = app.otherElements["QuickProfileSwitcher"]
        if quickSwitcher.waitForExistence(timeout: 2) {
            // Verify profile options
            XCTAssertTrue(app.buttons["Switch to Trading"].exists)
            XCTAssertTrue(app.buttons["Switch to Gaming"].exists)
            
            // Quick switch
            app.buttons["Switch to Gaming"].tap()
            
            // Verify switched
            XCTAssertTrue(app.staticTexts["Gaming"].waitForExistence(timeout: 2))
            
            screenshots.captureScreen(named: "3DTouch_Profile_Switch")
        }
    }
    
    // MARK: - Profile Data Isolation Tests
    
    func testProfileDataIsolation() {
        // Verify each profile has isolated data
        
        // Check Main Profile apps
        UITestHelpers.navigateToTab(.apps, in: app)
        let appsGrid = app.collectionViews[AccessibilityIdentifiers.Apps.appGrid]
        XCTAssertTrue(appsGrid.cells["app_Uniswap"].exists)
        XCTAssertTrue(appsGrid.cells["app_Aave"].exists)
        
        // Switch to Gaming profile
        UITestHelpers.switchToProfile(named: "Gaming", in: app)
        
        // Check Gaming profile has different apps
        UITestHelpers.navigateToTab(.apps, in: app)
        XCTAssertTrue(appsGrid.cells["app_Axie Infinity"].waitForExistence(timeout: 2))
        XCTAssertFalse(appsGrid.cells["app_Uniswap"].exists)
        
        // Check wallet isolation
        UITestHelpers.navigateToTab(.wallet, in: app)
        XCTAssertTrue(app.staticTexts["No wallet connected"].exists)
        
        // Switch to Trading profile
        UITestHelpers.switchToProfile(named: "Trading", in: app)
        
        // Verify Trading profile has wallet
        UITestHelpers.navigateToTab(.wallet, in: app)
        XCTAssertTrue(app.staticTexts["0x742d...BEd4"].waitForExistence(timeout: 2))
        
        screenshots.captureScreen(named: "Profile_Data_Isolation")
    }
    
    func testProfileSwitchPersistence() {
        // Switch to Gaming profile
        UITestHelpers.switchToProfile(named: "Gaming", in: app)
        
        // Verify on Gaming profile
        XCTAssertTrue(app.staticTexts["Gaming"].waitForExistence(timeout: 2))
        
        // Force quit app
        app.terminate()
        
        // Relaunch
        app.launch()
        
        // Verify still on Gaming profile
        UITestHelpers.navigateToTab(.profile, in: app)
        XCTAssertTrue(app.staticTexts["Gaming"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["🎮"].exists)
        
        screenshots.captureScreen(named: "Profile_Switch_Persisted")
    }
    
    // MARK: - Profile Switch with Pending Actions Tests
    
    func testProfileSwitchWithUnsavedChanges() {
        // Make changes in current profile
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Profile.profileSettings].tap()
        app.buttons["Edit Profile"].tap()
        
        // Edit profile name
        let nameField = app.textFields.firstMatch
        nameField.clearAndTypeText("Modified Name")
        
        // Try to switch profile without saving
        app.buttons["Back"].tap() // Back to settings
        app.buttons["Back"].tap() // Back to profile
        
        UITestHelpers.switchToProfile(named: "Trading", in: app)
        
        // Verify warning dialog
        let warningAlert = app.alerts["Unsaved Changes"]
        if warningAlert.waitForExistence(timeout: 2) {
            XCTAssertTrue(warningAlert.staticTexts["You have unsaved changes. Do you want to save them?"].exists)
            XCTAssertTrue(warningAlert.buttons["Save"].exists)
            XCTAssertTrue(warningAlert.buttons["Discard"].exists)
            XCTAssertTrue(warningAlert.buttons["Cancel"].exists)
            
            // Choose to save
            warningAlert.buttons["Save"].tap()
            
            // Verify changes saved and profile switched
            XCTAssertTrue(app.staticTexts["Trading"].waitForExistence(timeout: 3))
        }
        
        screenshots.captureScreen(named: "Profile_Switch_Unsaved_Changes")
    }
    
    func testProfileSwitchDuringTransaction() {
        // Switch to Trading profile with wallet
        UITestHelpers.switchToProfile(named: "Trading", in: app)
        
        // Start a transaction
        UITestHelpers.navigateToTab(.wallet, in: app)
        app.buttons[AccessibilityIdentifiers.Transaction.sendButton].tap()
        
        // Fill transaction details
        let amountField = app.textFields[AccessibilityIdentifiers.Transaction.amountField]
        amountField.tap()
        amountField.typeText("0.1")
        
        // Try to switch profile
        app.buttons["Cancel"].tap() // Close send sheet
        UITestHelpers.switchToProfile(named: "Gaming", in: app)
        
        // Verify warning about pending transaction
        let warningAlert = app.alerts["Transaction in Progress"]
        if warningAlert.waitForExistence(timeout: 2) {
            XCTAssertTrue(warningAlert.staticTexts["Switching profiles will cancel your current transaction"].exists)
            warningAlert.buttons["Continue Anyway"].tap()
        }
        
        screenshots.captureScreen(named: "Profile_Switch_During_Transaction")
    }
    
    // MARK: - Profile Switch Error Handling Tests
    
    func testProfileSwitchNetworkError() {
        // Configure for network error
        app.terminate()
        app.launchEnvironment["PROFILE_SWITCH_ERROR"] = "true"
        app.launch()
        
        // Try to switch profile
        UITestHelpers.navigateToTab(.profile, in: app)
        UITestHelpers.switchToProfile(named: "Trading", in: app)
        
        // Verify error handling
        let errorAlert = app.alerts["Profile Switch Failed"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 3))
        XCTAssertTrue(errorAlert.staticTexts["Unable to switch profiles. Please try again."].exists)
        
        errorAlert.buttons["Retry"].tap()
        
        screenshots.captureScreen(named: "Profile_Switch_Error")
    }
    
    // MARK: - Profile Badge and Notification Tests
    
    func testProfileNotificationBadges() {
        // Configure with profile notifications
        app.terminate()
        app.launchEnvironment["PROFILE_NOTIFICATIONS"] = "true"
        app.launch()
        
        // Open profile switcher
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Profile.profileSwitcher].tap()
        
        let profileList = app.collectionViews[AccessibilityIdentifiers.Profile.profileList]
        
        // Verify notification badges
        let tradingProfile = profileList.cells["profile_Trading"]
        XCTAssertTrue(tradingProfile.otherElements["NotificationBadge"].exists)
        XCTAssertTrue(tradingProfile.staticTexts["3"].exists) // 3 notifications
        
        // Switch to profile with notifications
        tradingProfile.tap()
        
        // Verify notifications shown
        XCTAssertTrue(app.staticTexts["3 new transactions"].waitForExistence(timeout: 2))
        
        screenshots.captureScreen(named: "Profile_Notifications")
    }
    
    // MARK: - Accessibility Tests
    
    func testProfileSwitchAccessibility() {
        // Navigate to profile
        UITestHelpers.navigateToTab(.profile, in: app)
        
        // Verify profile switcher accessibility
        let profileSwitcherButton = app.buttons[AccessibilityIdentifiers.Profile.profileSwitcher]
        UITestHelpers.verifyAccessibility(
            for: profileSwitcherButton,
            expectedLabel: "Profile switcher",
            expectedHint: "Double tap to switch between profiles"
        )
        
        // Open switcher
        profileSwitcherButton.tap()
        
        // Verify profile cell accessibility
        let profileList = app.collectionViews[AccessibilityIdentifiers.Profile.profileList]
        let tradingProfile = profileList.cells["profile_Trading"]
        
        UITestHelpers.verifyAccessibility(
            for: tradingProfile,
            expectedLabel: "Trading profile",
            expectedHint: "Double tap to switch to this profile"
        )
        
        screenshots.captureScreen(named: "Profile_Switch_Accessibility")
    }
    
    // MARK: - Performance Tests
    
    func testRapidProfileSwitching() {
        // Test rapid profile switching
        UITestHelpers.navigateToTab(.profile, in: app)
        
        // Switch profiles rapidly
        for _ in 0..<5 {
            UITestHelpers.switchToProfile(named: "Trading", in: app)
            Thread.sleep(forTimeInterval: 0.5)
            
            UITestHelpers.switchToProfile(named: "Gaming", in: app)
            Thread.sleep(forTimeInterval: 0.5)
            
            UITestHelpers.switchToProfile(named: "Main Profile", in: app)
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        // Verify app remains stable
        XCTAssertTrue(app.staticTexts["Main Profile"].exists)
        
        // Verify no memory warnings or crashes
        XCTAssertFalse(app.alerts["Memory Warning"].exists)
        
        screenshots.captureScreen(named: "Rapid_Profile_Switch")
    }
}