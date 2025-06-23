import XCTest

class OnboardingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        UITestMockDataProvider.configure(app: app, for: .firstTimeUser)
        
        // Reset app state for clean onboarding
        app.launchArguments.append("--reset-onboarding")
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - First Launch Experience Tests
    
    func testFirstLaunchShowsOnboarding() {
        // Verify onboarding screen appears
        let onboardingView = app.otherElements["OnboardingView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        // Verify first onboarding page
        XCTAssertTrue(app.staticTexts["Welcome to Interspace"].exists)
        XCTAssertTrue(app.staticTexts["Your gateway to decentralized applications"].exists)
        
        // Verify page indicators
        let pageIndicator = app.pageIndicators[AccessibilityIdentifiers.Onboarding.pageIndicator]
        XCTAssertTrue(pageIndicator.exists)
        XCTAssertEqual(pageIndicator.value as? String, "page 1 of 4")
        
        // Take screenshot of first onboarding screen
        screenshots.captureScreen(named: "Onboarding_Page1", description: "First onboarding screen")
    }
    
    func testOnboardingSwipeNavigation() {
        let onboardingView = app.otherElements["OnboardingView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        // Swipe to second page
        onboardingView.swipeLeft()
        
        // Verify second page content
        XCTAssertTrue(app.staticTexts["Manage Multiple Profiles"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Create separate profiles for trading, gaming, and more"].exists)
        
        let pageIndicator = app.pageIndicators[AccessibilityIdentifiers.Onboarding.pageIndicator]
        XCTAssertEqual(pageIndicator.value as? String, "page 2 of 4")
        
        screenshots.captureScreen(named: "Onboarding_Page2", description: "Profile management feature")
        
        // Swipe to third page
        onboardingView.swipeLeft()
        
        // Verify third page content
        XCTAssertTrue(app.staticTexts["Connect Your Wallets"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Support for MetaMask, Coinbase, and more"].exists)
        XCTAssertEqual(pageIndicator.value as? String, "page 3 of 4")
        
        screenshots.captureScreen(named: "Onboarding_Page3", description: "Wallet connection feature")
        
        // Swipe to fourth page
        onboardingView.swipeLeft()
        
        // Verify fourth page content
        XCTAssertTrue(app.staticTexts["Explore DeFi Apps"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Access your favorite decentralized applications"].exists)
        XCTAssertEqual(pageIndicator.value as? String, "page 4 of 4")
        
        screenshots.captureScreen(named: "Onboarding_Page4", description: "DeFi apps feature")
        
        // Verify Get Started button appears on last page
        let getStartedButton = app.buttons[AccessibilityIdentifiers.Onboarding.getStartedButton]
        XCTAssertTrue(getStartedButton.exists)
        XCTAssertTrue(getStartedButton.isEnabled)
    }
    
    func testOnboardingButtonNavigation() {
        let onboardingView = app.otherElements["OnboardingView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        // Test Next button navigation
        let nextButton = app.buttons[AccessibilityIdentifiers.Onboarding.nextButton]
        XCTAssertTrue(nextButton.exists)
        
        // Navigate through pages using Next button
        for page in 1...3 {
            nextButton.tap()
            
            let pageIndicator = app.pageIndicators[AccessibilityIdentifiers.Onboarding.pageIndicator]
            XCTAssertEqual(pageIndicator.value as? String, "page \(page + 1) of 4")
        }
        
        // Verify Next button is replaced by Get Started on last page
        XCTAssertFalse(nextButton.exists)
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Onboarding.getStartedButton].exists)
    }
    
    func testOnboardingSkipButton() {
        let onboardingView = app.otherElements["OnboardingView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        // Verify Skip button exists
        let skipButton = app.buttons[AccessibilityIdentifiers.Onboarding.skipButton]
        XCTAssertTrue(skipButton.exists)
        
        // Tap Skip button
        skipButton.tap()
        
        // Verify navigation to authentication screen
        let authTitle = app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle]
        XCTAssertTrue(authTitle.waitForExistence(timeout: 3))
        
        // Verify onboarding is dismissed
        XCTAssertFalse(app.otherElements["OnboardingView"].exists)
    }
    
    func testOnboardingGetStartedButton() {
        let onboardingView = app.otherElements["OnboardingView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        // Navigate to last page
        for _ in 1...3 {
            onboardingView.swipeLeft()
        }
        
        // Tap Get Started button
        let getStartedButton = app.buttons[AccessibilityIdentifiers.Onboarding.getStartedButton]
        getStartedButton.tap()
        
        // Verify navigation to authentication screen
        let authTitle = app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle]
        XCTAssertTrue(authTitle.waitForExistence(timeout: 3))
    }
    
    func testOnboardingPageIndicatorTap() {
        let onboardingView = app.otherElements["OnboardingView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        let pageIndicator = app.pageIndicators[AccessibilityIdentifiers.Onboarding.pageIndicator]
        
        // Tap on page indicator to navigate
        let indicatorBounds = pageIndicator.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5))
        indicatorBounds.tap()
        
        // Verify jumped to later page
        XCTAssertTrue(app.staticTexts["Explore DeFi Apps"].waitForExistence(timeout: 2))
    }
    
    func testOnboardingAccessibility() {
        let onboardingView = app.otherElements["OnboardingView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        // Verify VoiceOver labels
        let welcomeTitle = app.staticTexts["Welcome to Interspace"]
        UITestHelpers.verifyAccessibility(
            for: welcomeTitle,
            expectedLabel: "Welcome to Interspace"
        )
        
        let nextButton = app.buttons[AccessibilityIdentifiers.Onboarding.nextButton]
        UITestHelpers.verifyAccessibility(
            for: nextButton,
            expectedLabel: "Next",
            expectedHint: "Double tap to go to next onboarding screen"
        )
        
        let skipButton = app.buttons[AccessibilityIdentifiers.Onboarding.skipButton]
        UITestHelpers.verifyAccessibility(
            for: skipButton,
            expectedLabel: "Skip",
            expectedHint: "Double tap to skip onboarding"
        )
    }
    
    func testOnboardingRotation() {
        let onboardingView = app.otherElements["OnboardingView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        // Capture portrait screenshot
        screenshots.captureScreen(named: "Onboarding_Portrait")
        
        // Rotate to landscape
        XCUIDevice.shared.orientation = .landscapeLeft
        
        // Wait for rotation animation
        Thread.sleep(forTimeInterval: 0.5)
        
        // Verify onboarding adapts to landscape
        XCTAssertTrue(app.staticTexts["Welcome to Interspace"].exists)
        
        // Capture landscape screenshot
        screenshots.captureScreen(named: "Onboarding_Landscape")
        
        // Rotate back to portrait
        XCUIDevice.shared.orientation = .portrait
    }
    
    func testOnboardingCompletionTracking() {
        // Complete onboarding
        let onboardingView = app.otherElements["OnboardingView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        // Navigate through all pages
        for _ in 1...3 {
            app.buttons[AccessibilityIdentifiers.Onboarding.nextButton].tap()
        }
        
        // Complete onboarding
        app.buttons[AccessibilityIdentifiers.Onboarding.getStartedButton].tap()
        
        // Verify onboarding completion is tracked
        // (This would be verified through analytics or user defaults in real implementation)
        XCTAssertTrue(app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle].waitForExistence(timeout: 3))
        
        // Restart app
        app.terminate()
        app.launch()
        
        // Verify onboarding doesn't show again
        XCTAssertFalse(app.otherElements["OnboardingView"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle].exists)
    }
    
    func testOnboardingInterruption() {
        let onboardingView = app.otherElements["OnboardingView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        // Navigate to second page
        onboardingView.swipeLeft()
        
        // Force quit app
        app.terminate()
        
        // Relaunch app
        app.launch()
        
        // Verify onboarding resumes from beginning
        XCTAssertTrue(app.otherElements["OnboardingView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Welcome to Interspace"].exists)
        
        let pageIndicator = app.pageIndicators[AccessibilityIdentifiers.Onboarding.pageIndicator]
        XCTAssertEqual(pageIndicator.value as? String, "page 1 of 4")
    }
    
    func testOnboardingAnimations() {
        let onboardingView = app.otherElements["OnboardingView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        // Document animation states
        screenshots.documentFlow(named: "OnboardingAnimations") {
            // Initial state
            Thread.sleep(forTimeInterval: 0.5)
            
            // Swipe animation
            onboardingView.swipeLeft()
            Thread.sleep(forTimeInterval: 0.3) // Mid-animation
            
            // Settled state
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
}

// MARK: - Onboarding Content Tests

extension OnboardingUITests {
    
    func testOnboardingContentAccuracy() {
        let onboardingView = app.otherElements["OnboardingView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        // Page 1: Welcome
        XCTAssertTrue(app.images["onboarding_welcome_image"].exists)
        XCTAssertTrue(app.staticTexts["Welcome to Interspace"].exists)
        XCTAssertTrue(app.staticTexts["Your gateway to decentralized applications"].exists)
        
        // Page 2: Profiles
        onboardingView.swipeLeft()
        XCTAssertTrue(app.images["onboarding_profiles_image"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Manage Multiple Profiles"].exists)
        XCTAssertTrue(app.staticTexts["Create separate profiles for trading, gaming, and more"].exists)
        
        // Page 3: Wallets
        onboardingView.swipeLeft()
        XCTAssertTrue(app.images["onboarding_wallets_image"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Connect Your Wallets"].exists)
        XCTAssertTrue(app.staticTexts["Support for MetaMask, Coinbase, and more"].exists)
        
        // Page 4: Apps
        onboardingView.swipeLeft()
        XCTAssertTrue(app.images["onboarding_apps_image"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Explore DeFi Apps"].exists)
        XCTAssertTrue(app.staticTexts["Access your favorite decentralized applications"].exists)
    }
    
    func testOnboardingLocalization() {
        // This test would verify different language support
        // For now, we'll just verify English content exists
        let onboardingView = app.otherElements["OnboardingView"]
        XCTAssertTrue(onboardingView.waitForExistence(timeout: 5))
        
        // Verify all text is in English
        XCTAssertTrue(app.buttons["Skip"].exists)
        XCTAssertTrue(app.buttons["Next"].exists)
        XCTAssertTrue(app.staticTexts["Welcome to Interspace"].exists)
    }
}