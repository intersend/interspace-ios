import XCTest

class SocialLoginUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launchEnvironment = ["MOCK_API": "true", "MOCK_SOCIAL_AUTH": "true"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Google Sign In Tests
    
    func testGoogleSignInButtonPresence() {
        // Wait for auth screen
        let authTitle = app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle]
        XCTAssertTrue(authTitle.waitForExistence(timeout: 5))
        
        // Verify Google Sign In button
        let googleButton = app.buttons[AccessibilityIdentifiers.Authentication.googleButton]
        XCTAssertTrue(googleButton.exists)
        XCTAssertTrue(googleButton.isEnabled)
        
        // Verify button has Google branding
        XCTAssertTrue(app.images["google"].exists)
        
        // Verify accessibility
        UITestHelpers.verifyAccessibility(
            for: googleButton,
            expectedLabel: AccessibilityLabels.Authentication.continueWithGoogle,
            expectedHint: AccessibilityHints.Authentication.googleButton
        )
        
        screenshots.captureScreen(named: "GoogleSignIn_Button")
    }
    
    func testGoogleSignInFlow() {
        // Tap Google Sign In button
        let googleButton = app.buttons[AccessibilityIdentifiers.Authentication.googleButton]
        googleButton.tap()
        
        // In mock mode, we simulate the Google Sign In web view
        let mockGoogleWebView = app.webViews["MockGoogleSignIn"]
        XCTAssertTrue(mockGoogleWebView.waitForExistence(timeout: 3))
        
        // Verify mock Google sign in page elements
        XCTAssertTrue(app.staticTexts["Sign in with Google"].exists)
        XCTAssertTrue(app.textFields["Email or phone"].exists)
        XCTAssertTrue(app.buttons["Next"].exists)
        
        screenshots.captureScreen(named: "GoogleSignIn_MockWebView")
        
        // Enter email
        let emailField = app.textFields["Email or phone"]
        emailField.tap()
        emailField.typeText("testuser@gmail.com")
        
        // Tap Next
        app.buttons["Next"].tap()
        
        // Mock password screen
        let passwordField = app.secureTextFields["Enter your password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 2))
        passwordField.tap()
        passwordField.typeText("testpassword")
        
        // Complete sign in
        app.buttons["Sign in"].tap()
        
        // Mock consent screen
        let consentButton = app.buttons["Allow"]
        if consentButton.waitForExistence(timeout: 2) {
            consentButton.tap()
        }
        
        // Verify successful authentication
        let loadingIndicator = app.progressIndicators["AuthLoadingIndicator"]
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: 1))
        
        // Verify navigation to main app
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        
        // Verify user is logged in with Google
        UITestHelpers.navigateToTab(.profile, in: app)
        XCTAssertTrue(app.staticTexts["testuser@gmail.com"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.images["google_account_badge"].exists)
        
        screenshots.captureScreen(named: "GoogleSignIn_Success")
    }
    
    func testGoogleSignInCancellation() {
        // Tap Google Sign In button
        app.buttons[AccessibilityIdentifiers.Authentication.googleButton].tap()
        
        // Wait for mock web view
        let mockGoogleWebView = app.webViews["MockGoogleSignIn"]
        XCTAssertTrue(mockGoogleWebView.waitForExistence(timeout: 3))
        
        // Tap cancel/close button
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists)
        cancelButton.tap()
        
        // Verify returned to authentication screen
        let authTitle = app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle]
        XCTAssertTrue(authTitle.waitForExistence(timeout: 2))
        
        // Verify Google button is still available
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Authentication.googleButton].exists)
    }
    
    func testGoogleSignInError() {
        // Configure for error scenario
        app.terminate()
        app.launchEnvironment["GOOGLE_AUTH_ERROR"] = "true"
        app.launch()
        
        // Tap Google Sign In button
        app.buttons[AccessibilityIdentifiers.Authentication.googleButton].tap()
        
        // Complete mock sign in flow
        let mockGoogleWebView = app.webViews["MockGoogleSignIn"]
        XCTAssertTrue(mockGoogleWebView.waitForExistence(timeout: 3))
        
        // Simulate error response
        app.buttons["MockErrorTrigger"].tap()
        
        // Verify error alert
        let errorAlert = app.alerts["Authentication Error"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(errorAlert.staticTexts["Failed to sign in with Google"].exists)
        
        screenshots.captureScreen(named: "GoogleSignIn_Error")
        
        // Dismiss alert
        errorAlert.buttons["OK"].tap()
        
        // Verify still on auth screen
        XCTAssertTrue(app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle].exists)
    }
    
    // MARK: - Apple Sign In Tests
    
    func testAppleSignInButtonPresence() {
        // Wait for auth screen
        let authTitle = app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle]
        XCTAssertTrue(authTitle.waitForExistence(timeout: 5))
        
        // Verify Apple Sign In button
        let appleButton = app.buttons[AccessibilityIdentifiers.Authentication.appleButton]
        XCTAssertTrue(appleButton.exists)
        XCTAssertTrue(appleButton.isEnabled)
        
        // Verify button has Apple branding
        XCTAssertTrue(app.images["apple"].exists)
        
        // Verify accessibility
        UITestHelpers.verifyAccessibility(
            for: appleButton,
            expectedLabel: AccessibilityLabels.Authentication.continueWithApple,
            expectedHint: AccessibilityHints.Authentication.appleButton
        )
        
        screenshots.captureScreen(named: "AppleSignIn_Button")
    }
    
    func testAppleSignInFlow() {
        // Tap Apple Sign In button
        let appleButton = app.buttons[AccessibilityIdentifiers.Authentication.appleButton]
        appleButton.tap()
        
        // In mock mode, we simulate the Apple Sign In sheet
        let authSheet = app.sheets["Sign In with Apple ID"]
        XCTAssertTrue(authSheet.waitForExistence(timeout: 3))
        
        // Verify authorization options
        XCTAssertTrue(authSheet.staticTexts["Use your Apple ID to sign in to Interspace"].exists)
        XCTAssertTrue(authSheet.buttons["Continue"].exists)
        
        // Verify privacy options
        let shareEmailOption = authSheet.buttons["Share My Email"]
        let hideEmailOption = authSheet.buttons["Hide My Email"]
        XCTAssertTrue(shareEmailOption.exists || hideEmailOption.exists)
        
        screenshots.captureScreen(named: "AppleSignIn_AuthSheet")
        
        // Select share email option if available
        if shareEmailOption.exists {
            shareEmailOption.tap()
        }
        
        // Continue with Face ID / Touch ID (mocked)
        authSheet.buttons["Continue"].tap()
        
        // Mock biometric authentication
        let biometricPrompt = app.alerts["Sign In with Apple"]
        if biometricPrompt.waitForExistence(timeout: 2) {
            // In mock mode, we auto-approve
            Thread.sleep(forTimeInterval: 1)
        }
        
        // Verify successful authentication
        let loadingIndicator = app.progressIndicators["AuthLoadingIndicator"]
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: 1))
        
        // Verify navigation to main app
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        
        // Verify user is logged in with Apple
        UITestHelpers.navigateToTab(.profile, in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "@privaterelay.appleid.com")).element.waitForExistence(timeout: 2))
        XCTAssertTrue(app.images["apple_account_badge"].exists)
        
        screenshots.captureScreen(named: "AppleSignIn_Success")
    }
    
    func testAppleSignInWithHideEmail() {
        // Tap Apple Sign In button
        app.buttons[AccessibilityIdentifiers.Authentication.appleButton].tap()
        
        // Wait for authorization sheet
        let authSheet = app.sheets["Sign In with Apple ID"]
        XCTAssertTrue(authSheet.waitForExistence(timeout: 3))
        
        // Select hide email option
        let hideEmailOption = authSheet.buttons["Hide My Email"]
        if hideEmailOption.exists {
            hideEmailOption.tap()
        }
        
        // Continue
        authSheet.buttons["Continue"].tap()
        
        // Complete authentication
        Thread.sleep(forTimeInterval: 1) // Mock biometric
        
        // Verify navigation to main app
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        
        // Verify private relay email is used
        UITestHelpers.navigateToTab(.profile, in: app)
        let privateRelayEmail = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "@privaterelay.appleid.com")).element
        XCTAssertTrue(privateRelayEmail.waitForExistence(timeout: 2))
    }
    
    func testAppleSignInCancellation() {
        // Tap Apple Sign In button
        app.buttons[AccessibilityIdentifiers.Authentication.appleButton].tap()
        
        // Wait for authorization sheet
        let authSheet = app.sheets["Sign In with Apple ID"]
        XCTAssertTrue(authSheet.waitForExistence(timeout: 3))
        
        // Tap cancel
        authSheet.buttons["Cancel"].tap()
        
        // Verify returned to authentication screen
        let authTitle = app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle]
        XCTAssertTrue(authTitle.waitForExistence(timeout: 2))
        
        // Verify Apple button is still available
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Authentication.appleButton].exists)
    }
    
    func testAppleSignInBiometricFailure() {
        // Configure for biometric failure
        app.terminate()
        app.launchEnvironment["BIOMETRIC_AUTH_FAIL"] = "true"
        app.launch()
        
        // Tap Apple Sign In button
        app.buttons[AccessibilityIdentifiers.Authentication.appleButton].tap()
        
        // Wait for authorization sheet
        let authSheet = app.sheets["Sign In with Apple ID"]
        XCTAssertTrue(authSheet.waitForExistence(timeout: 3))
        
        // Continue
        authSheet.buttons["Continue"].tap()
        
        // Verify biometric failure alert
        let failureAlert = app.alerts["Authentication Failed"]
        XCTAssertTrue(failureAlert.waitForExistence(timeout: 3))
        XCTAssertTrue(failureAlert.staticTexts["Face ID authentication failed"].exists || 
                      failureAlert.staticTexts["Touch ID authentication failed"].exists)
        
        // Try again
        failureAlert.buttons["Try Again"].tap()
        
        // Verify back at authorization sheet
        XCTAssertTrue(authSheet.exists)
    }
    
    // MARK: - Social Account Linking Tests
    
    func testLinkGoogleAccountToExistingProfile() {
        // Start with email authenticated user
        UITestMockDataProvider.configure(app: app, for: .returningUser)
        app.launch()
        
        // Navigate to profile settings
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Profile.profileSettings].tap()
        
        // Tap linked accounts
        app.buttons[AccessibilityIdentifiers.Profile.linkedAccountsList].tap()
        
        // Add Google account
        app.buttons[AccessibilityIdentifiers.Profile.addAccountButton].tap()
        app.buttons["Link Google Account"].tap()
        
        // Complete Google sign in flow
        let mockGoogleWebView = app.webViews["MockGoogleSignIn"]
        XCTAssertTrue(mockGoogleWebView.waitForExistence(timeout: 3))
        app.buttons["MockGoogleSignInSuccess"].tap()
        
        // Verify account linked
        XCTAssertTrue(app.cells["google_account_cell"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["testuser@gmail.com"].exists)
        
        screenshots.captureScreen(named: "LinkedGoogleAccount")
    }
    
    func testMultipleSocialAccountsInProfile() {
        // Configure with multi-account profile
        UITestMockDataProvider.configure(app: app, for: .multiProfile)
        app.launch()
        
        // Navigate to profile
        UITestHelpers.navigateToTab(.profile, in: app)
        
        // Verify multiple social accounts displayed
        XCTAssertTrue(app.images["google_account_badge"].exists)
        XCTAssertTrue(app.images["apple_account_badge"].exists)
        XCTAssertTrue(app.staticTexts["2 linked accounts"].exists)
        
        screenshots.captureScreen(named: "MultipleSocialAccounts")
    }
    
    // MARK: - Social Login Accessibility Tests
    
    func testSocialLoginAccessibility() {
        // Verify VoiceOver support for social login buttons
        let googleButton = app.buttons[AccessibilityIdentifiers.Authentication.googleButton]
        let appleButton = app.buttons[AccessibilityIdentifiers.Authentication.appleButton]
        
        // Test with VoiceOver gestures
        UITestHelpers.simulateVoiceOverSwipe(in: app)
        
        // Verify buttons are in accessibility order
        XCTAssertTrue(googleButton.isAccessibilityElement)
        XCTAssertTrue(appleButton.isAccessibilityElement)
        
        // Verify traits
        XCTAssertTrue(googleButton.isHittable)
        XCTAssertTrue(appleButton.isHittable)
    }
}