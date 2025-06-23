import XCTest

class EmailAuthenticationUITests: XCTestCase {
    
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
    
    // MARK: - Email Registration Tests
    
    func testEmailRegistrationFlow() {
        // Wait for auth screen
        let authTitle = app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle]
        XCTAssertTrue(authTitle.waitForExistence(timeout: 5))
        
        // Tap email button
        let emailButton = app.buttons[AccessibilityIdentifiers.Authentication.emailButton]
        emailButton.tap()
        
        // Verify email input screen
        let emailView = app.otherElements["EmailAuthView"]
        XCTAssertTrue(emailView.waitForExistence(timeout: 2))
        
        XCTAssertTrue(app.staticTexts["Enter your email"].exists)
        XCTAssertTrue(app.staticTexts["We'll send you a verification code"].exists)
        
        // Enter email
        let emailTextField = app.textFields[AccessibilityIdentifiers.Authentication.emailTextField]
        XCTAssertTrue(emailTextField.exists)
        emailTextField.tap()
        emailTextField.typeText("newuser@example.com")
        
        // Verify email validation
        XCTAssertTrue(app.images["email_valid_checkmark"].waitForExistence(timeout: 1))
        
        screenshots.captureScreen(named: "Email_Registration_Input")
        
        // Send code
        let sendCodeButton = app.buttons[AccessibilityIdentifiers.Authentication.sendCodeButton]
        XCTAssertTrue(sendCodeButton.isEnabled)
        sendCodeButton.tap()
        
        // Verify loading state
        let loadingIndicator = app.progressIndicators["SendingCode"]
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: 1))
        
        // Verify code input screen
        let codeView = app.otherElements["VerificationCodeView"]
        XCTAssertTrue(codeView.waitForExistence(timeout: 3))
        
        XCTAssertTrue(app.staticTexts["Enter verification code"].exists)
        XCTAssertTrue(app.staticTexts["Code sent to newuser@example.com"].exists)
        
        // Verify code input field
        let codeField = app.textFields[AccessibilityIdentifiers.Authentication.verificationCodeField]
        XCTAssertTrue(codeField.exists)
        
        // Enter code
        codeField.tap()
        codeField.typeText("123456")
        
        screenshots.captureScreen(named: "Email_Verification_Code")
        
        // Verify code
        let verifyButton = app.buttons[AccessibilityIdentifiers.Authentication.verifyButton]
        verifyButton.tap()
        
        // Verify successful registration
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        
        // Should show profile creation for new users
        let createProfileView = app.otherElements["CreateProfileView"]
        XCTAssertTrue(createProfileView.waitForExistence(timeout: 3))
        
        screenshots.captureScreen(named: "Email_Registration_Success")
    }
    
    func testEmailLoginFlow() {
        // Configure for existing user
        app.terminate()
        app.launchEnvironment["EXISTING_USER"] = "true"
        app.launch()
        
        // Perform email login
        UITestHelpers.performEmailLogin(email: "existing@example.com", code: "123456", in: app)
        
        // Verify successful login
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        
        // Should go directly to home for existing users
        let homeTab = app.tabBars.buttons[AccessibilityIdentifiers.Navigation.homeTab]
        XCTAssertTrue(homeTab.isSelected)
        
        screenshots.captureScreen(named: "Email_Login_Success")
    }
    
    // MARK: - Email Validation Tests
    
    func testEmailValidation() {
        // Navigate to email auth
        app.buttons[AccessibilityIdentifiers.Authentication.emailButton].tap()
        
        let emailTextField = app.textFields[AccessibilityIdentifiers.Authentication.emailTextField]
        let sendCodeButton = app.buttons[AccessibilityIdentifiers.Authentication.sendCodeButton]
        
        // Test invalid email formats
        let invalidEmails = [
            "notanemail",
            "missing@domain",
            "@example.com",
            "spaces in@email.com",
            "double@@example.com"
        ]
        
        for invalidEmail in invalidEmails {
            emailTextField.tap()
            emailTextField.clearAndTypeText(invalidEmail)
            
            // Verify send button is disabled
            XCTAssertFalse(sendCodeButton.isEnabled)
            
            // Verify error indicator
            XCTAssertTrue(app.images["email_invalid_icon"].exists)
        }
        
        // Test valid email
        emailTextField.clearAndTypeText("valid@example.com")
        XCTAssertTrue(sendCodeButton.isEnabled)
        XCTAssertTrue(app.images["email_valid_checkmark"].exists)
        
        screenshots.captureScreen(named: "Email_Validation")
    }
    
    func testEmailDomainBlacklist() {
        // Navigate to email auth
        app.buttons[AccessibilityIdentifiers.Authentication.emailButton].tap()
        
        let emailTextField = app.textFields[AccessibilityIdentifiers.Authentication.emailTextField]
        
        // Test blacklisted domains
        emailTextField.tap()
        emailTextField.typeText("test@tempmail.com")
        
        app.buttons[AccessibilityIdentifiers.Authentication.sendCodeButton].tap()
        
        // Verify error
        let errorAlert = app.alerts["Invalid Email"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(errorAlert.staticTexts["Please use a permanent email address"].exists)
        
        errorAlert.buttons["OK"].tap()
        
        screenshots.captureScreen(named: "Email_Blacklist_Error")
    }
    
    // MARK: - Verification Code Tests
    
    func testVerificationCodeInput() {
        // Navigate to code screen
        UITestHelpers.performEmailLogin(email: "test@example.com", code: "", in: app)
        
        let codeField = app.textFields[AccessibilityIdentifiers.Authentication.verificationCodeField]
        
        // Test code formatting
        codeField.tap()
        codeField.typeText("123")
        
        // Verify partial code state
        XCTAssertFalse(app.buttons[AccessibilityIdentifiers.Authentication.verifyButton].isEnabled)
        
        // Complete code
        codeField.typeText("456")
        
        // Verify button enabled with complete code
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Authentication.verifyButton].isEnabled)
        
        // Test auto-submit (if implemented)
        Thread.sleep(forTimeInterval: 0.5)
        
        screenshots.captureScreen(named: "Verification_Code_Complete")
    }
    
    func testResendCode() {
        // Navigate to code screen
        UITestHelpers.performEmailLogin(email: "test@example.com", code: "", in: app)
        
        // Verify resend button
        let resendButton = app.buttons[AccessibilityIdentifiers.Authentication.resendCodeButton]
        XCTAssertTrue(resendButton.waitForExistence(timeout: 2))
        
        // Initially might be disabled (cooldown)
        if !resendButton.isEnabled {
            // Wait for cooldown
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Resend in")).element.exists)
            
            // Wait for it to become enabled
            let enabledPredicate = NSPredicate(format: "isEnabled == true")
            let expectation = XCTNSPredicateExpectation(predicate: enabledPredicate, object: resendButton)
            let result = XCTWaiter().wait(for: [expectation], timeout: 31) // 30 second cooldown + buffer
            XCTAssertEqual(result, .completed)
        }
        
        // Tap resend
        resendButton.tap()
        
        // Verify success message
        XCTAssertTrue(app.staticTexts["New code sent"].waitForExistence(timeout: 2))
        
        screenshots.captureScreen(named: "Code_Resent")
    }
    
    func testIncorrectVerificationCode() {
        // Navigate to code screen
        UITestHelpers.performEmailLogin(email: "test@example.com", code: "", in: app)
        
        // Enter incorrect code
        let codeField = app.textFields[AccessibilityIdentifiers.Authentication.verificationCodeField]
        codeField.tap()
        codeField.typeText("000000")
        
        app.buttons[AccessibilityIdentifiers.Authentication.verifyButton].tap()
        
        // Verify error
        let errorAlert = app.alerts["Verification Failed"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(errorAlert.staticTexts["Invalid verification code"].exists)
        
        errorAlert.buttons["Try Again"].tap()
        
        // Verify code field is cleared
        XCTAssertEqual(codeField.value as? String, "")
        
        screenshots.captureScreen(named: "Invalid_Code_Error")
    }
    
    // MARK: - Session Management Tests
    
    func testRememberMe() {
        // Perform login with remember me
        app.buttons[AccessibilityIdentifiers.Authentication.emailButton].tap()
        
        // Enter email
        let emailTextField = app.textFields[AccessibilityIdentifiers.Authentication.emailTextField]
        emailTextField.tap()
        emailTextField.typeText("remember@example.com")
        
        // Check if remember me toggle exists
        let rememberMeSwitch = app.switches["Remember Me"]
        if rememberMeSwitch.exists {
            rememberMeSwitch.tap()
        }
        
        app.buttons[AccessibilityIdentifiers.Authentication.sendCodeButton].tap()
        
        // Complete verification
        let codeField = app.textFields[AccessibilityIdentifiers.Authentication.verificationCodeField]
        codeField.tap()
        codeField.typeText("123456")
        app.buttons[AccessibilityIdentifiers.Authentication.verifyButton].tap()
        
        // Wait for main app
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        
        // Force quit and relaunch
        app.terminate()
        app.launch()
        
        // Should stay logged in
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle].exists)
        
        screenshots.captureScreen(named: "Remember_Me_Success")
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkErrorDuringEmailAuth() {
        // Configure for network error
        app.terminate()
        app.launchEnvironment["NETWORK_ERROR"] = "true"
        app.launch()
        
        // Try email auth
        app.buttons[AccessibilityIdentifiers.Authentication.emailButton].tap()
        
        let emailTextField = app.textFields[AccessibilityIdentifiers.Authentication.emailTextField]
        emailTextField.tap()
        emailTextField.typeText("test@example.com")
        
        app.buttons[AccessibilityIdentifiers.Authentication.sendCodeButton].tap()
        
        // Verify network error
        let errorAlert = app.alerts["Network Error"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 3))
        XCTAssertTrue(errorAlert.staticTexts["Unable to connect to server"].exists)
        
        errorAlert.buttons["Retry"].tap()
        
        screenshots.captureScreen(named: "Email_Network_Error")
    }
    
    func testRateLimiting() {
        // Configure for rate limit scenario
        app.terminate()
        app.launchEnvironment["RATE_LIMITED"] = "true"
        app.launch()
        
        // Try multiple code requests
        app.buttons[AccessibilityIdentifiers.Authentication.emailButton].tap()
        
        let emailTextField = app.textFields[AccessibilityIdentifiers.Authentication.emailTextField]
        emailTextField.tap()
        emailTextField.typeText("ratelimit@example.com")
        
        app.buttons[AccessibilityIdentifiers.Authentication.sendCodeButton].tap()
        
        // Verify rate limit error
        let errorAlert = app.alerts["Too Many Requests"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(errorAlert.staticTexts["Please wait before requesting another code"].exists)
        
        errorAlert.buttons["OK"].tap()
        
        // Verify cooldown timer shown
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Try again in")).element.exists)
        
        screenshots.captureScreen(named: "Rate_Limit_Error")
    }
    
    // MARK: - Accessibility Tests
    
    func testEmailAuthAccessibility() {
        // Navigate to email auth
        app.buttons[AccessibilityIdentifiers.Authentication.emailButton].tap()
        
        // Verify accessibility labels
        let emailTextField = app.textFields[AccessibilityIdentifiers.Authentication.emailTextField]
        UITestHelpers.verifyAccessibility(
            for: emailTextField,
            expectedLabel: "Email address",
            expectedHint: "Enter your email address to sign in or create an account"
        )
        
        let sendCodeButton = app.buttons[AccessibilityIdentifiers.Authentication.sendCodeButton]
        UITestHelpers.verifyAccessibility(
            for: sendCodeButton,
            expectedLabel: "Send verification code",
            expectedHint: "Double tap to send a verification code to your email"
        )
        
        // Test with VoiceOver navigation
        UITestHelpers.simulateVoiceOverSwipe(in: app)
        
        screenshots.captureScreen(named: "Email_Auth_Accessibility")
    }
    
    // MARK: - Back Navigation Tests
    
    func testBackNavigationDuringEmailAuth() {
        // Navigate to email auth
        app.buttons[AccessibilityIdentifiers.Authentication.emailButton].tap()
        
        // Verify back button
        let backButton = app.buttons[AccessibilityIdentifiers.Authentication.backButton]
        XCTAssertTrue(backButton.exists)
        
        // Go back
        backButton.tap()
        
        // Should return to main auth screen
        XCTAssertTrue(app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle].waitForExistence(timeout: 2))
        
        // Navigate to verification code screen
        app.buttons[AccessibilityIdentifiers.Authentication.emailButton].tap()
        let emailTextField = app.textFields[AccessibilityIdentifiers.Authentication.emailTextField]
        emailTextField.tap()
        emailTextField.typeText("test@example.com")
        app.buttons[AccessibilityIdentifiers.Authentication.sendCodeButton].tap()
        
        // Go back from code screen
        app.buttons[AccessibilityIdentifiers.Authentication.backButton].tap()
        
        // Should return to email input with email preserved
        XCTAssertTrue(emailTextField.waitForExistence(timeout: 2))
        XCTAssertEqual(emailTextField.value as? String, "test@example.com")
        
        screenshots.captureScreen(named: "Email_Back_Navigation")
    }
}