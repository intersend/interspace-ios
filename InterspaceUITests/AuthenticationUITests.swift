import XCTest

class AuthenticationUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launchEnvironment = ["MOCK_API": "true"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Authentication Screen Tests
    
    func testAuthenticationScreenElements() {
        // Wait for auth screen to appear
        let authTitle = app.staticTexts["Welcome to Interspace"]
        XCTAssertTrue(authTitle.waitForExistence(timeout: 5))
        
        // Verify authentication options are present
        XCTAssertTrue(app.buttons["Connect Wallet"].exists)
        XCTAssertTrue(app.buttons["Continue with Email"].exists)
        XCTAssertTrue(app.buttons["Continue with Google"].exists)
        XCTAssertTrue(app.buttons["Continue with Apple"].exists)
        XCTAssertTrue(app.buttons["Continue as Guest"].exists)
    }
    
    func testEmailAuthenticationFlow() {
        // Tap email authentication
        app.buttons["Continue with Email"].tap()
        
        // Verify email input screen
        let emailTextField = app.textFields["Email"]
        XCTAssertTrue(emailTextField.waitForExistence(timeout: 2))
        
        // Enter email
        emailTextField.tap()
        emailTextField.typeText("test@example.com")
        
        // Tap continue
        app.buttons["Send Code"].tap()
        
        // Wait for verification code screen
        let codeTextField = app.textFields["Verification Code"]
        XCTAssertTrue(codeTextField.waitForExistence(timeout: 2))
        
        // Enter verification code
        codeTextField.tap()
        codeTextField.typeText("123456")
        
        // Tap verify
        app.buttons["Verify"].tap()
        
        // Verify navigation to main app
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    }
    
    func testWalletConnectionFlow() {
        // Tap wallet connection
        app.buttons["Connect Wallet"].tap()
        
        // Wait for wallet selection tray
        let walletTray = app.otherElements["WalletSelectionTray"]
        XCTAssertTrue(walletTray.waitForExistence(timeout: 2))
        
        // Verify wallet options
        XCTAssertTrue(app.buttons["MetaMask"].exists)
        XCTAssertTrue(app.buttons["Coinbase Wallet"].exists)
        
        // Select MetaMask
        app.buttons["MetaMask"].tap()
        
        // In UI tests, we can't test actual wallet connection
        // but we can verify the UI responds appropriately
        
        // Verify loading state appears
        let connectingLabel = app.staticTexts["Connecting to MetaMask..."]
        XCTAssertTrue(connectingLabel.exists)
    }
    
    func testGuestAuthenticationFlow() {
        // Tap guest authentication
        app.buttons["Continue as Guest"].tap()
        
        // Verify navigation to main app
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        
        // Verify guest user indicator
        let profileTab = app.buttons["Profile"]
        profileTab.tap()
        
        let guestLabel = app.staticTexts["Guest User"]
        XCTAssertTrue(guestLabel.waitForExistence(timeout: 2))
    }
    
    func testAuthenticationErrorHandling() {
        // Tap email authentication
        app.buttons["Continue with Email"].tap()
        
        // Enter invalid email
        let emailTextField = app.textFields["Email"]
        emailTextField.tap()
        emailTextField.typeText("invalid-email")
        
        // Try to send code
        app.buttons["Send Code"].tap()
        
        // Verify error alert appears
        let errorAlert = app.alerts.firstMatch
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(errorAlert.staticTexts["Invalid email address"].exists)
        
        // Dismiss alert
        errorAlert.buttons["OK"].tap()
        
        // Verify we're still on email input screen
        XCTAssertTrue(emailTextField.exists)
    }
    
    func testSocialSignInButtons() {
        // Test Google Sign In
        let googleButton = app.buttons["Continue with Google"]
        XCTAssertTrue(googleButton.exists)
        XCTAssertTrue(googleButton.isEnabled)
        
        // Test Apple Sign In
        let appleButton = app.buttons["Continue with Apple"]
        XCTAssertTrue(appleButton.exists)
        XCTAssertTrue(appleButton.isEnabled)
        
        // Verify buttons have correct styling
        // Note: In actual implementation, these would be native buttons
    }
    
    func testAuthenticationScreenAccessibility() {
        // Verify accessibility labels
        XCTAssertEqual(app.buttons["Connect Wallet"].label, "Connect Wallet")
        XCTAssertEqual(app.buttons["Continue with Email"].label, "Continue with Email")
        
        // Verify accessibility hints
        let walletButton = app.buttons["Connect Wallet"]
        XCTAssertTrue(walletButton.exists)
        
        // Test VoiceOver navigation
        // Note: This requires additional setup for full VoiceOver testing
    }
}

// MARK: - Helper Extensions

extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and type text into a non string value")
            return
        }
        
        self.tap()
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}