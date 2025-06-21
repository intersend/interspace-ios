import XCTest

class ProfileManagementUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "Authenticated-User"]
        app.launchEnvironment = ["MOCK_API": "true"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Profile Creation Tests
    
    func testFirstTimeUserProfileCreation() {
        // For new users, should show profile creation screen
        let createProfileTitle = app.staticTexts["Create Your First Profile"]
        XCTAssertTrue(createProfileTitle.waitForExistence(timeout: 5))
        
        // Verify onboarding text
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "organize your crypto accounts")).element.exists)
        
        // Enter profile name
        let profileNameField = app.textFields["Profile name"]
        XCTAssertTrue(profileNameField.exists)
        profileNameField.tap()
        profileNameField.typeText("My Trading Profile")
        
        // Create profile
        let createButton = app.buttons["Create Profile"]
        XCTAssertTrue(createButton.isEnabled)
        createButton.tap()
        
        // Verify navigation to main app
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    }
    
    func testProfileSwitching() {
        // Navigate to profile tab
        app.tabBars.buttons["Profile"].tap()
        
        // Open profile switcher
        let profileSwitcherButton = app.buttons["ProfileSwitcher"]
        XCTAssertTrue(profileSwitcherButton.waitForExistence(timeout: 2))
        profileSwitcherButton.tap()
        
        // Wait for profile list
        let profileList = app.collectionViews["ProfileList"]
        XCTAssertTrue(profileList.waitForExistence(timeout: 2))
        
        // Verify multiple profiles exist
        let tradingProfile = profileList.cells.staticTexts["Trading"]
        let gamingProfile = profileList.cells.staticTexts["Gaming"]
        
        XCTAssertTrue(tradingProfile.exists)
        XCTAssertTrue(gamingProfile.exists)
        
        // Switch to gaming profile
        gamingProfile.tap()
        
        // Verify profile switch animation
        let switchingIndicator = app.progressIndicators["ProfileSwitchProgress"]
        XCTAssertTrue(switchingIndicator.waitForExistence(timeout: 1))
        
        // Verify profile switched
        XCTAssertTrue(app.staticTexts["Gaming"].waitForExistence(timeout: 3))
    }
    
    func testCreateAdditionalProfile() {
        // Navigate to profile tab
        app.tabBars.buttons["Profile"].tap()
        
        // Open profile settings
        let settingsButton = app.buttons["ProfileSettings"]
        settingsButton.tap()
        
        // Tap create new profile
        let createNewButton = app.buttons["Create New Profile"]
        XCTAssertTrue(createNewButton.waitForExistence(timeout: 2))
        createNewButton.tap()
        
        // Enter new profile details
        let profileNameField = app.textFields["Profile name"]
        profileNameField.tap()
        profileNameField.typeText("DeFi Portfolio")
        
        // Select icon
        let iconPicker = app.buttons["SelectIcon"]
        iconPicker.tap()
        
        let rocketIcon = app.buttons["🚀"]
        XCTAssertTrue(rocketIcon.waitForExistence(timeout: 2))
        rocketIcon.tap()
        
        // Select color
        let colorPicker = app.buttons["SelectColor"]
        colorPicker.tap()
        
        let purpleColor = app.buttons["Purple"]
        purpleColor.tap()
        
        // Create profile
        app.buttons["Create"].tap()
        
        // Verify profile created and active
        XCTAssertTrue(app.staticTexts["DeFi Portfolio"].waitForExistence(timeout: 3))
    }
    
    func testProfileSettings() {
        // Navigate to profile tab
        app.tabBars.buttons["Profile"].tap()
        
        // Open profile settings
        let settingsButton = app.buttons["ProfileSettings"]
        settingsButton.tap()
        
        // Verify settings options
        XCTAssertTrue(app.staticTexts["Profile Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Edit Profile"].exists)
        XCTAssertTrue(app.buttons["Linked Accounts"].exists)
        XCTAssertTrue(app.buttons["Privacy Settings"].exists)
        XCTAssertTrue(app.buttons["Delete Profile"].exists)
    }
    
    func testEditProfile() {
        // Navigate to profile settings
        app.tabBars.buttons["Profile"].tap()
        app.buttons["ProfileSettings"].tap()
        
        // Tap edit profile
        app.buttons["Edit Profile"].tap()
        
        // Edit profile name
        let nameField = app.textFields.firstMatch
        nameField.clearAndTypeText("Updated Profile Name")
        
        // Change icon
        app.buttons["ChangeIcon"].tap()
        app.buttons["💎"].tap()
        
        // Save changes
        app.buttons["Save"].tap()
        
        // Verify changes saved
        XCTAssertTrue(app.staticTexts["Updated Profile Name"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["💎"].exists)
    }
    
    func testProfileDeletion() {
        // Navigate to profile settings
        app.tabBars.buttons["Profile"].tap()
        app.buttons["ProfileSettings"].tap()
        
        // Tap delete profile
        app.buttons["Delete Profile"].tap()
        
        // Verify confirmation dialog
        let confirmationAlert = app.alerts["Delete Profile"]
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(confirmationAlert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "This action cannot be undone")).element.exists)
        
        // Cancel deletion
        confirmationAlert.buttons["Cancel"].tap()
        
        // Verify profile still exists
        XCTAssertTrue(app.buttons["Edit Profile"].exists)
        
        // Test actual deletion
        app.buttons["Delete Profile"].tap()
        confirmationAlert.buttons["Delete"].tap()
        
        // Verify profile deleted and switched to another
        XCTAssertFalse(app.staticTexts["Deleted Profile"].exists)
    }
}

// MARK: - Profile List UI Tests

extension ProfileManagementUITests {
    
    func testProfileListDisplay() {
        // Open profile switcher
        app.tabBars.buttons["Profile"].tap()
        app.buttons["ProfileSwitcher"].tap()
        
        let profileList = app.collectionViews["ProfileList"]
        
        // Verify profile cells have correct elements
        let firstProfile = profileList.cells.element(boundBy: 0)
        XCTAssertTrue(firstProfile.exists)
        
        // Check for profile icon
        XCTAssertTrue(firstProfile.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[\\p{Emoji}]$")).element.exists)
        
        // Check for profile name
        XCTAssertTrue(firstProfile.staticTexts.matching(NSPredicate(format: "label.length > 0")).element.exists)
        
        // Check for active indicator
        let activeIndicator = firstProfile.images["ActiveIndicator"]
        XCTAssertTrue(activeIndicator.exists)
    }
    
    func testProfileQuickActions() {
        // Open profile switcher
        app.tabBars.buttons["Profile"].tap()
        app.buttons["ProfileSwitcher"].tap()
        
        let profileList = app.collectionViews["ProfileList"]
        let profileCell = profileList.cells.element(boundBy: 1) // Non-active profile
        
        // Long press for quick actions
        profileCell.press(forDuration: 1.0)
        
        // Verify quick action menu
        let quickActionMenu = app.otherElements["QuickActionMenu"]
        XCTAssertTrue(quickActionMenu.waitForExistence(timeout: 2))
        
        // Verify quick actions
        XCTAssertTrue(app.buttons["Switch to Profile"].exists)
        XCTAssertTrue(app.buttons["Edit Profile"].exists)
        XCTAssertTrue(app.buttons["View Details"].exists)
    }
}