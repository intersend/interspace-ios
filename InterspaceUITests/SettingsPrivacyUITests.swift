import XCTest

class SettingsPrivacyUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        UITestMockDataProvider.configure(app: app, for: .returningUser)
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Settings Access Tests
    
    func testSettingsAccess() {
        // Navigate to profile tab
        UITestHelpers.navigateToTab(.profile, in: app)
        
        // Tap settings button
        let settingsButton = app.buttons[AccessibilityIdentifiers.Navigation.settingsButton]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))
        settingsButton.tap()
        
        // Verify settings view
        let settingsView = app.otherElements[AccessibilityIdentifiers.Settings.settingsView]
        XCTAssertTrue(settingsView.waitForExistence(timeout: 2))
        
        // Verify navigation title
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        
        screenshots.captureScreen(named: "Settings_Main")
    }
    
    func testSettingsSections() {
        // Navigate to settings
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Navigation.settingsButton].tap()
        
        // Verify all sections exist
        let tableView = app.tables.firstMatch
        
        // Account section
        XCTAssertTrue(tableView.cells["Account Settings"].exists)
        XCTAssertTrue(tableView.cells["Linked Accounts"].exists)
        XCTAssertTrue(tableView.cells["Email Preferences"].exists)
        
        // Privacy section
        XCTAssertTrue(tableView.cells["Privacy Settings"].exists)
        XCTAssertTrue(tableView.cells["Data & Analytics"].exists)
        XCTAssertTrue(tableView.cells["Blocked Apps"].exists)
        
        // Security section
        XCTAssertTrue(tableView.cells["Security Settings"].exists)
        XCTAssertTrue(tableView.cells["Biometric Authentication"].exists)
        XCTAssertTrue(tableView.cells["Two-Factor Authentication"].exists)
        
        // General section
        XCTAssertTrue(tableView.cells["Notifications"].exists)
        XCTAssertTrue(tableView.cells["Appearance"].exists)
        XCTAssertTrue(tableView.cells["Language"].exists)
        
        // About section
        XCTAssertTrue(tableView.cells["About"].exists)
        XCTAssertTrue(tableView.cells["Help & Support"].exists)
        XCTAssertTrue(tableView.cells["Terms of Service"].exists)
        XCTAssertTrue(tableView.cells["Privacy Policy"].exists)
        
        screenshots.captureScreen(named: "Settings_Sections")
    }
    
    // MARK: - Privacy Settings Tests
    
    func testPrivacySettings() {
        // Navigate to privacy settings
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Navigation.settingsButton].tap()
        
        let privacyCell = app.cells["Privacy Settings"]
        privacyCell.tap()
        
        // Verify privacy settings view
        let privacyView = app.otherElements[AccessibilityIdentifiers.Settings.privacySection]
        XCTAssertTrue(privacyView.waitForExistence(timeout: 2))
        
        // Verify privacy options
        XCTAssertTrue(app.switches["Share Analytics Data"].exists)
        XCTAssertTrue(app.switches["Personalized Recommendations"].exists)
        XCTAssertTrue(app.switches["Show Online Status"].exists)
        XCTAssertTrue(app.switches["Allow Profile Discovery"].exists)
        
        // Test toggle
        let analyticsSwitch = app.switches["Share Analytics Data"]
        let initialValue = analyticsSwitch.value as? String == "1"
        analyticsSwitch.tap()
        
        // Verify confirmation dialog for sensitive settings
        if app.alerts["Update Privacy Settings"].exists {
            XCTAssertTrue(app.alerts["Update Privacy Settings"].staticTexts["This will affect how we collect and use your data"].exists)
            app.alerts["Update Privacy Settings"].buttons["Confirm"].tap()
        }
        
        let newValue = analyticsSwitch.value as? String == "1"
        XCTAssertNotEqual(initialValue, newValue)
        
        screenshots.captureScreen(named: "Privacy_Settings")
    }
    
    func testDataManagement() {
        // Navigate to settings
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Navigation.settingsButton].tap()
        
        // Navigate to data & analytics
        app.cells["Data & Analytics"].tap()
        
        // Verify data management options
        XCTAssertTrue(app.buttons["Download My Data"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Clear Cache"].exists)
        XCTAssertTrue(app.buttons["Delete Account Data"].exists)
        
        // Test download data
        app.buttons["Download My Data"].tap()
        
        // Verify download confirmation
        let downloadAlert = app.alerts["Download Your Data"]
        XCTAssertTrue(downloadAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(downloadAlert.staticTexts["We'll prepare your data and send a download link to your email"].exists)
        
        downloadAlert.buttons["Request Download"].tap()
        
        // Verify success message
        XCTAssertTrue(app.staticTexts["Data download requested"].waitForExistence(timeout: 2))
        
        screenshots.captureScreen(named: "Data_Download_Request")
    }
    
    // MARK: - Security Settings Tests
    
    func testBiometricAuthentication() {
        // Navigate to security settings
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Navigation.settingsButton].tap()
        app.cells["Biometric Authentication"].tap()
        
        // Verify biometric settings
        let biometricView = app.otherElements["BiometricSettingsView"]
        XCTAssertTrue(biometricView.waitForExistence(timeout: 2))
        
        // Check for Face ID or Touch ID based on device
        let faceIDSwitch = app.switches["Use Face ID"]
        let touchIDSwitch = app.switches["Use Touch ID"]
        
        XCTAssertTrue(faceIDSwitch.exists || touchIDSwitch.exists)
        
        if faceIDSwitch.exists {
            // Test Face ID toggle
            let initialValue = faceIDSwitch.value as? String == "1"
            faceIDSwitch.tap()
            
            // Mock biometric authentication
            if app.alerts["Enable Face ID"].waitForExistence(timeout: 2) {
                app.alerts["Enable Face ID"].buttons["Enable"].tap()
            }
            
            let newValue = faceIDSwitch.value as? String == "1"
            XCTAssertNotEqual(initialValue, newValue)
        }
        
        // Verify additional options
        XCTAssertTrue(app.switches["Require for Transactions"].exists)
        XCTAssertTrue(app.switches["Lock on Background"].exists)
        
        screenshots.captureScreen(named: "Biometric_Settings")
    }
    
    func testTwoFactorAuthentication() {
        // Navigate to 2FA settings
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Navigation.settingsButton].tap()
        app.cells["Two-Factor Authentication"].tap()
        
        // Verify 2FA view
        let twoFAView = app.otherElements["TwoFactorAuthView"]
        XCTAssertTrue(twoFAView.waitForExistence(timeout: 2))
        
        // Check current status
        if app.staticTexts["2FA is not enabled"].exists {
            // Enable 2FA
            app.buttons["Enable 2FA"].tap()
            
            // Verify setup flow
            XCTAssertTrue(app.staticTexts["Set Up Two-Factor Authentication"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.images["QRCode2FA"].exists)
            XCTAssertTrue(app.staticTexts["Scan this QR code with your authenticator app"].exists)
            
            // Copy secret key
            app.buttons["Copy Secret Key"].tap()
            XCTAssertTrue(app.staticTexts["Copied!"].waitForExistence(timeout: 1))
            
            // Enter verification code
            let codeField = app.textFields["Verification Code"]
            codeField.tap()
            codeField.typeText("123456")
            
            app.buttons["Verify & Enable"].tap()
            
            // Verify success
            XCTAssertTrue(app.staticTexts["2FA Enabled Successfully"].waitForExistence(timeout: 2))
        } else {
            // 2FA already enabled - test disable
            XCTAssertTrue(app.buttons["Disable 2FA"].exists)
            XCTAssertTrue(app.staticTexts["2FA is enabled"].exists)
        }
        
        screenshots.captureScreen(named: "TwoFA_Settings")
    }
    
    // MARK: - Notification Settings Tests
    
    func testNotificationSettings() {
        // Navigate to notification settings
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Navigation.settingsButton].tap()
        app.cells["Notifications"].tap()
        
        // Verify notification settings
        let notificationView = app.otherElements["NotificationSettingsView"]
        XCTAssertTrue(notificationView.waitForExistence(timeout: 2))
        
        // Verify notification toggles
        let notificationsToggle = app.switches[AccessibilityIdentifiers.Settings.notificationsToggle]
        XCTAssertTrue(notificationsToggle.exists)
        
        // Verify notification categories
        XCTAssertTrue(app.switches["Transaction Alerts"].exists)
        XCTAssertTrue(app.switches["Price Alerts"].exists)
        XCTAssertTrue(app.switches["Security Alerts"].exists)
        XCTAssertTrue(app.switches["Marketing Updates"].exists)
        
        // Test master toggle
        let initialValue = notificationsToggle.value as? String == "1"
        notificationsToggle.tap()
        
        // If disabling, verify warning
        if initialValue {
            let warningAlert = app.alerts["Disable Notifications"]
            if warningAlert.waitForExistence(timeout: 1) {
                XCTAssertTrue(warningAlert.staticTexts["You won't receive any notifications"].exists)
                warningAlert.buttons["Disable"].tap()
            }
        }
        
        screenshots.captureScreen(named: "Notification_Settings")
    }
    
    // MARK: - Appearance Settings Tests
    
    func testAppearanceSettings() {
        // Navigate to appearance settings
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Navigation.settingsButton].tap()
        app.cells["Appearance"].tap()
        
        // Verify appearance options
        let appearanceView = app.otherElements["AppearanceSettingsView"]
        XCTAssertTrue(appearanceView.waitForExistence(timeout: 2))
        
        // Verify theme options
        XCTAssertTrue(app.buttons["Light"].exists)
        XCTAssertTrue(app.buttons["Dark"].exists)
        XCTAssertTrue(app.buttons["System"].exists)
        
        // Test dark mode toggle
        let darkModeToggle = app.switches[AccessibilityIdentifiers.Settings.darkModeToggle]
        if darkModeToggle.exists {
            darkModeToggle.tap()
            
            // Verify theme change animation
            Thread.sleep(forTimeInterval: 0.5)
        } else {
            // Use theme buttons
            app.buttons["Dark"].tap()
        }
        
        // Verify app icon options
        XCTAssertTrue(app.staticTexts["App Icon"].exists)
        XCTAssertTrue(app.collectionViews["AppIconPicker"].exists)
        
        screenshots.captureScreen(named: "Appearance_Settings")
    }
    
    // MARK: - Account Management Tests
    
    func testLogout() {
        // Navigate to settings
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Navigation.settingsButton].tap()
        
        // Scroll to logout button
        let tableView = app.tables.firstMatch
        tableView.swipeUp()
        
        // Tap logout
        let logoutButton = app.buttons[AccessibilityIdentifiers.Settings.logoutButton]
        XCTAssertTrue(logoutButton.waitForExistence(timeout: 2))
        logoutButton.tap()
        
        // Verify confirmation
        let logoutAlert = app.alerts["Log Out"]
        XCTAssertTrue(logoutAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(logoutAlert.staticTexts["Are you sure you want to log out?"].exists)
        
        // Confirm logout
        logoutAlert.buttons["Log Out"].tap()
        
        // Verify returned to auth screen
        let authTitle = app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle]
        XCTAssertTrue(authTitle.waitForExistence(timeout: 3))
        
        screenshots.captureScreen(named: "Logout_Success")
    }
    
    func testDeleteAccount() {
        // Navigate to settings
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Navigation.settingsButton].tap()
        
        // Scroll to delete account
        let tableView = app.tables.firstMatch
        tableView.swipeUp()
        
        // Tap delete account
        let deleteButton = app.buttons[AccessibilityIdentifiers.Settings.deleteAccountButton]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()
        
        // Verify delete account flow
        let deleteView = app.otherElements["DeleteAccountView"]
        XCTAssertTrue(deleteView.waitForExistence(timeout: 2))
        
        // Verify warnings
        XCTAssertTrue(app.staticTexts["Delete Your Account"].exists)
        XCTAssertTrue(app.staticTexts["This action cannot be undone"].exists)
        XCTAssertTrue(app.staticTexts["All your data will be permanently deleted"].exists)
        
        // Verify confirmation steps
        XCTAssertTrue(app.textFields["Type DELETE to confirm"].exists)
        
        // Type confirmation
        let confirmField = app.textFields["Type DELETE to confirm"]
        confirmField.tap()
        confirmField.typeText("DELETE")
        
        // Verify delete button becomes enabled
        let finalDeleteButton = app.buttons["Delete My Account"]
        XCTAssertTrue(finalDeleteButton.isEnabled)
        
        screenshots.captureScreen(named: "Delete_Account_Confirmation")
        
        // Don't actually delete in test
    }
    
    // MARK: - Help & Support Tests
    
    func testHelpAndSupport() {
        // Navigate to settings
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Navigation.settingsButton].tap()
        
        // Tap help & support
        app.cells["Help & Support"].tap()
        
        // Verify help options
        let helpView = app.otherElements["HelpSupportView"]
        XCTAssertTrue(helpView.waitForExistence(timeout: 2))
        
        XCTAssertTrue(app.buttons["FAQ"].exists)
        XCTAssertTrue(app.buttons["Contact Support"].exists)
        XCTAssertTrue(app.buttons["Report a Bug"].exists)
        XCTAssertTrue(app.buttons["Feature Request"].exists)
        
        // Test FAQ
        app.buttons["FAQ"].tap()
        XCTAssertTrue(app.navigationBars["Frequently Asked Questions"].waitForExistence(timeout: 2))
        
        screenshots.captureScreen(named: "Help_FAQ")
    }
    
    // MARK: - Developer Settings Tests
    
    func testDeveloperSettings() {
        // Enable developer mode first
        app.terminate()
        app.launchArguments.append("--enable-developer-mode")
        app.launch()
        
        // Navigate to settings
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Navigation.settingsButton].tap()
        
        // Scroll to find developer settings
        let tableView = app.tables.firstMatch
        tableView.swipeUp()
        
        // Verify developer settings section
        let developerCell = app.cells["Developer Settings"]
        if developerCell.waitForExistence(timeout: 2) {
            developerCell.tap()
            
            // Verify developer options
            let developerView = app.otherElements[AccessibilityIdentifiers.Settings.developerSection]
            XCTAssertTrue(developerView.waitForExistence(timeout: 2))
            
            XCTAssertTrue(app.switches["Enable Logging"].exists)
            XCTAssertTrue(app.switches["Show Network Activity"].exists)
            XCTAssertTrue(app.buttons["Export Logs"].exists)
            XCTAssertTrue(app.buttons["Clear Cache"].exists)
            XCTAssertTrue(app.buttons["Reset App State"].exists)
            
            screenshots.captureScreen(named: "Developer_Settings")
        }
    }
}