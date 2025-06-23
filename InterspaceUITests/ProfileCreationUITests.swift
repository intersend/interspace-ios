import XCTest

class ProfileCreationUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "First-Time-User"]
        app.launchEnvironment = ["MOCK_API": "true"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - First Profile Creation Tests
    
    func testFirstProfileCreation() {
        // Complete authentication first
        UITestHelpers.performEmailLogin(email: "newuser@example.com", code: "123456", in: app)
        
        // Verify profile creation screen appears
        let createProfileView = app.otherElements["CreateProfileView"]
        XCTAssertTrue(createProfileView.waitForExistence(timeout: 5))
        
        // Verify onboarding content
        XCTAssertTrue(app.staticTexts["Create Your First Profile"].exists)
        XCTAssertTrue(app.staticTexts["Profiles help you organize your crypto accounts and activities"].exists)
        
        // Enter profile name
        let profileNameField = app.textFields[AccessibilityIdentifiers.Profile.profileNameField]
        XCTAssertTrue(profileNameField.exists)
        profileNameField.tap()
        profileNameField.typeText("My Main Profile")
        
        screenshots.captureScreen(named: "First_Profile_Name")
        
        // Select icon
        let iconPicker = app.buttons[AccessibilityIdentifiers.Profile.profileIconPicker]
        XCTAssertTrue(iconPicker.exists)
        iconPicker.tap()
        
        // Verify icon picker
        let iconPickerView = app.otherElements["IconPickerView"]
        XCTAssertTrue(iconPickerView.waitForExistence(timeout: 2))
        
        // Select an icon
        let rocketIcon = app.buttons["🚀"]
        XCTAssertTrue(rocketIcon.exists)
        rocketIcon.tap()
        
        // Verify icon selected
        XCTAssertTrue(app.staticTexts["🚀"].waitForExistence(timeout: 1))
        
        // Select color
        let colorPicker = app.buttons[AccessibilityIdentifiers.Profile.profileColorPicker]
        colorPicker.tap()
        
        // Verify color picker
        let colorPickerView = app.otherElements["ColorPickerView"]
        XCTAssertTrue(colorPickerView.waitForExistence(timeout: 2))
        
        // Select blue color
        let blueColor = app.buttons["Blue"]
        blueColor.tap()
        
        screenshots.captureScreen(named: "First_Profile_Customized")
        
        // Create profile
        let createButton = app.buttons[AccessibilityIdentifiers.Profile.createProfileButton]
        XCTAssertTrue(createButton.isEnabled)
        createButton.tap()
        
        // Verify profile created and navigation to main app
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        
        // Verify profile is active
        UITestHelpers.navigateToTab(.profile, in: app)
        XCTAssertTrue(app.staticTexts["My Main Profile"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["🚀"].exists)
        
        screenshots.captureScreen(named: "First_Profile_Created")
    }
    
    func testProfileNameValidation() {
        // Navigate to profile creation
        UITestHelpers.performEmailLogin(email: "newuser@example.com", code: "123456", in: app)
        
        let profileNameField = app.textFields[AccessibilityIdentifiers.Profile.profileNameField]
        let createButton = app.buttons[AccessibilityIdentifiers.Profile.createProfileButton]
        
        // Test empty name
        XCTAssertFalse(createButton.isEnabled)
        
        // Test name too short
        profileNameField.tap()
        profileNameField.typeText("A")
        XCTAssertFalse(createButton.isEnabled)
        XCTAssertTrue(app.staticTexts["Name must be at least 2 characters"].exists)
        
        // Test name too long
        profileNameField.clearAndTypeText(String(repeating: "A", count: 31))
        XCTAssertFalse(createButton.isEnabled)
        XCTAssertTrue(app.staticTexts["Name must be 30 characters or less"].exists)
        
        // Test valid name
        profileNameField.clearAndTypeText("Valid Profile Name")
        XCTAssertTrue(createButton.isEnabled)
        
        // Test special characters
        profileNameField.clearAndTypeText("Profile #1 🎮")
        XCTAssertTrue(createButton.isEnabled)
        
        screenshots.captureScreen(named: "Profile_Name_Validation")
    }
    
    // MARK: - Icon Selection Tests
    
    func testIconPicker() {
        // Navigate to profile creation
        UITestHelpers.performEmailLogin(email: "newuser@example.com", code: "123456", in: app)
        
        // Open icon picker
        app.buttons[AccessibilityIdentifiers.Profile.profileIconPicker].tap()
        
        let iconPickerView = app.otherElements["IconPickerView"]
        XCTAssertTrue(iconPickerView.waitForExistence(timeout: 2))
        
        // Verify icon categories
        XCTAssertTrue(app.segmentedControls["IconCategories"].exists)
        XCTAssertTrue(app.buttons["Popular"].exists)
        XCTAssertTrue(app.buttons["Finance"].exists)
        XCTAssertTrue(app.buttons["Gaming"].exists)
        XCTAssertTrue(app.buttons["Tech"].exists)
        
        // Switch to Gaming category
        app.buttons["Gaming"].tap()
        
        // Verify gaming icons
        XCTAssertTrue(app.buttons["🎮"].exists)
        XCTAssertTrue(app.buttons["🎯"].exists)
        XCTAssertTrue(app.buttons["🎲"].exists)
        XCTAssertTrue(app.buttons["🏆"].exists)
        
        // Test icon search
        let searchBar = app.searchFields["Search icons"]
        if searchBar.exists {
            searchBar.tap()
            searchBar.typeText("rocket")
            
            // Verify filtered results
            XCTAssertTrue(app.buttons["🚀"].waitForExistence(timeout: 1))
            XCTAssertFalse(app.buttons["🎮"].exists)
        }
        
        screenshots.captureScreen(named: "Icon_Picker")
        
        // Select an icon
        app.buttons["🎮"].tap()
        
        // Verify icon selected
        XCTAssertFalse(iconPickerView.exists)
        XCTAssertTrue(app.staticTexts["🎮"].exists)
    }
    
    func testCustomEmoji() {
        // Navigate to profile creation
        UITestHelpers.performEmailLogin(email: "newuser@example.com", code: "123456", in: app)
        
        // Enter profile name with emoji
        let profileNameField = app.textFields[AccessibilityIdentifiers.Profile.profileNameField]
        profileNameField.tap()
        profileNameField.typeText("Gaming Profile")
        
        // Open icon picker
        app.buttons[AccessibilityIdentifiers.Profile.profileIconPicker].tap()
        
        // Look for custom emoji option
        let customEmojiButton = app.buttons["Custom Emoji"]
        if customEmojiButton.waitForExistence(timeout: 2) {
            customEmojiButton.tap()
            
            // This would open system emoji keyboard
            // In test, we simulate selection
            app.textFields["Enter emoji"].tap()
            app.textFields["Enter emoji"].typeText("🦄")
            
            app.buttons["Use This Emoji"].tap()
        }
        
        screenshots.captureScreen(named: "Custom_Emoji")
    }
    
    // MARK: - Color Selection Tests
    
    func testColorPicker() {
        // Navigate to profile creation
        UITestHelpers.performEmailLogin(email: "newuser@example.com", code: "123456", in: app)
        
        // Enter profile name
        let profileNameField = app.textFields[AccessibilityIdentifiers.Profile.profileNameField]
        profileNameField.tap()
        profileNameField.typeText("Colorful Profile")
        
        // Open color picker
        app.buttons[AccessibilityIdentifiers.Profile.profileColorPicker].tap()
        
        let colorPickerView = app.otherElements["ColorPickerView"]
        XCTAssertTrue(colorPickerView.waitForExistence(timeout: 2))
        
        // Verify preset colors
        let presetColors = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Gray"]
        for color in presetColors {
            XCTAssertTrue(app.buttons[color].exists)
        }
        
        // Test color preview
        app.buttons["Purple"].tap()
        Thread.sleep(forTimeInterval: 0.3) // Allow preview animation
        
        app.buttons["Green"].tap()
        Thread.sleep(forTimeInterval: 0.3)
        
        screenshots.captureScreen(named: "Color_Picker")
        
        // Test custom color (if available)
        let customColorButton = app.buttons["Custom Color"]
        if customColorButton.exists {
            customColorButton.tap()
            
            // Would show color wheel/slider
            let colorSlider = app.sliders["Hue"]
            if colorSlider.exists {
                colorSlider.adjust(toNormalizedSliderPosition: 0.7)
            }
            
            app.buttons["Select Color"].tap()
        }
        
        // Verify color selected
        XCTAssertFalse(colorPickerView.exists)
    }
    
    // MARK: - Additional Profile Creation Tests
    
    func testCreateMultipleProfiles() {
        // Setup with existing profile
        app.terminate()
        UITestMockDataProvider.configure(app: app, for: .returningUser)
        app.launch()
        
        // Navigate to profile
        UITestHelpers.navigateToTab(.profile, in: app)
        
        // Access profile creation
        app.buttons[AccessibilityIdentifiers.Profile.profileSwitcher].tap()
        app.buttons[AccessibilityIdentifiers.Profile.createProfileButton].tap()
        
        // Create Trading profile
        UITestHelpers.createProfile(
            name: "Trading Portfolio",
            icon: "📈",
            color: "Green",
            in: app
        )
        
        // Verify profile created
        XCTAssertTrue(app.staticTexts["Trading Portfolio"].waitForExistence(timeout: 3))
        
        // Create another profile
        app.buttons[AccessibilityIdentifiers.Profile.profileSwitcher].tap()
        app.buttons[AccessibilityIdentifiers.Profile.createProfileButton].tap()
        
        // Create Gaming profile
        UITestHelpers.createProfile(
            name: "Gaming Wallet",
            icon: "🎮",
            color: "Purple",
            in: app
        )
        
        // Verify multiple profiles exist
        app.buttons[AccessibilityIdentifiers.Profile.profileSwitcher].tap()
        
        let profileList = app.collectionViews[AccessibilityIdentifiers.Profile.profileList]
        XCTAssertTrue(profileList.waitForExistence(timeout: 2))
        XCTAssertTrue(profileList.cells.count >= 3)
        
        screenshots.captureScreen(named: "Multiple_Profiles")
    }
    
    func testProfileCreationLimits() {
        // Configure with max profiles
        app.terminate()
        app.launchEnvironment["MAX_PROFILES"] = "true"
        app.launch()
        
        // Navigate to profile
        UITestHelpers.navigateToTab(.profile, in: app)
        
        // Try to create new profile
        app.buttons[AccessibilityIdentifiers.Profile.profileSwitcher].tap()
        
        // Verify limit message
        if app.buttons[AccessibilityIdentifiers.Profile.createProfileButton].exists {
            app.buttons[AccessibilityIdentifiers.Profile.createProfileButton].tap()
            
            let limitAlert = app.alerts["Profile Limit Reached"]
            XCTAssertTrue(limitAlert.waitForExistence(timeout: 2))
            XCTAssertTrue(limitAlert.staticTexts["You can create up to 10 profiles"].exists)
            
            limitAlert.buttons["OK"].tap()
        } else {
            // Create button might be disabled/hidden
            XCTAssertTrue(app.staticTexts["Maximum profiles reached"].exists)
        }
        
        screenshots.captureScreen(named: "Profile_Limit")
    }
    
    // MARK: - Profile Templates Tests
    
    func testProfileTemplates() {
        // Navigate to profile creation
        UITestHelpers.performEmailLogin(email: "newuser@example.com", code: "123456", in: app)
        
        // Look for templates option
        let templatesButton = app.buttons["Use Template"]
        if templatesButton.waitForExistence(timeout: 2) {
            templatesButton.tap()
            
            // Verify template options
            let templatesView = app.otherElements["ProfileTemplatesView"]
            XCTAssertTrue(templatesView.waitForExistence(timeout: 2))
            
            XCTAssertTrue(app.cells["template_Trading"].exists)
            XCTAssertTrue(app.cells["template_Gaming"].exists)
            XCTAssertTrue(app.cells["template_DeFi"].exists)
            XCTAssertTrue(app.cells["template_NFT"].exists)
            
            // Select trading template
            app.cells["template_Trading"].tap()
            
            // Verify template applied
            XCTAssertEqual(app.textFields[AccessibilityIdentifiers.Profile.profileNameField].value as? String, "Trading")
            XCTAssertTrue(app.staticTexts["📈"].exists)
            
            screenshots.captureScreen(named: "Profile_Template_Applied")
        }
    }
    
    // MARK: - Profile Import Tests
    
    func testImportProfileFromBackup() {
        // Navigate to profile creation
        UITestHelpers.performEmailLogin(email: "newuser@example.com", code: "123456", in: app)
        
        // Look for import option
        let importButton = app.buttons["Import Profile"]
        if importButton.waitForExistence(timeout: 2) {
            importButton.tap()
            
            // Verify import options
            let importView = app.otherElements["ImportProfileView"]
            XCTAssertTrue(importView.waitForExistence(timeout: 2))
            
            XCTAssertTrue(app.buttons["Import from iCloud"].exists)
            XCTAssertTrue(app.buttons["Import from File"].exists)
            XCTAssertTrue(app.buttons["Scan QR Code"].exists)
            
            // Test QR code import
            app.buttons["Scan QR Code"].tap()
            
            // In test environment, simulate QR scan
            if app.otherElements["QRScannerView"].waitForExistence(timeout: 2) {
                // Mock successful scan
                Thread.sleep(forTimeInterval: 1)
                
                // Verify imported profile data
                XCTAssertTrue(app.staticTexts["Profile Imported Successfully"].waitForExistence(timeout: 2))
            }
            
            screenshots.captureScreen(named: "Profile_Import")
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testProfileCreationAccessibility() {
        // Navigate to profile creation
        UITestHelpers.performEmailLogin(email: "newuser@example.com", code: "123456", in: app)
        
        // Verify VoiceOver labels
        let profileNameField = app.textFields[AccessibilityIdentifiers.Profile.profileNameField]
        UITestHelpers.verifyAccessibility(
            for: profileNameField,
            expectedLabel: "Profile name",
            expectedHint: "Enter a name for your profile"
        )
        
        let iconPicker = app.buttons[AccessibilityIdentifiers.Profile.profileIconPicker]
        UITestHelpers.verifyAccessibility(
            for: iconPicker,
            expectedLabel: "Select icon",
            expectedHint: "Double tap to choose an icon for your profile"
        )
        
        // Test with large text
        profileNameField.tap()
        profileNameField.typeText("Accessibility Test Profile")
        
        // Verify text scales properly
        screenshots.captureScreen(named: "Profile_Creation_Accessibility")
    }
}