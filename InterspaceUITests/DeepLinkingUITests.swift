import XCTest

class DeepLinkingUITests: XCTestCase {
    
    var app: XCUIApplication!
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launchEnvironment = ["MOCK_API": "true"]
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Deep Link URL Tests
    
    func testDeepLinkToProfile() {
        // Launch app normally first to ensure it's installed
        app.launch()
        app.terminate()
        
        // Open deep link via Safari
        safari.launch()
        
        // Navigate to URL bar
        let urlBar = safari.otherElements["URL"]
        urlBar.tap()
        
        // Enter deep link URL
        urlBar.typeText("interspace://profile")
        safari.buttons["Go"].tap()
        
        // Handle open app prompt
        let openButton = safari.buttons["Open"]
        if openButton.waitForExistence(timeout: 3) {
            openButton.tap()
        }
        
        // Verify app opens to profile tab
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        let profileTab = app.tabBars.buttons[AccessibilityIdentifiers.Navigation.profileTab]
        XCTAssertTrue(profileTab.isSelected)
        
        screenshots.captureScreen(named: "DeepLink_Profile")
    }
    
    func testDeepLinkToWallet() {
        // Launch and terminate app
        app.launch()
        app.terminate()
        
        // Open wallet deep link
        safari.launch()
        let urlBar = safari.otherElements["URL"]
        urlBar.tap()
        urlBar.typeText("interspace://wallet")
        safari.buttons["Go"].tap()
        
        // Open in app
        if safari.buttons["Open"].waitForExistence(timeout: 3) {
            safari.buttons["Open"].tap()
        }
        
        // Verify wallet tab is selected
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        let walletTab = app.tabBars.buttons[AccessibilityIdentifiers.Navigation.walletTab]
        XCTAssertTrue(walletTab.isSelected)
        
        screenshots.captureScreen(named: "DeepLink_Wallet")
    }
    
    func testDeepLinkToSpecificApp() {
        // Launch with authenticated user
        UITestMockDataProvider.configure(app: app, for: .returningUser)
        app.launch()
        app.terminate()
        
        // Open deep link to specific app
        safari.launch()
        let urlBar = safari.otherElements["URL"]
        urlBar.tap()
        urlBar.typeText("interspace://app/uniswap")
        safari.buttons["Go"].tap()
        
        // Open in app
        if safari.buttons["Open"].waitForExistence(timeout: 3) {
            safari.buttons["Open"].tap()
        }
        
        // Verify app opens Uniswap in web view
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        let webView = app.webViews[AccessibilityIdentifiers.Apps.appWebView]
        XCTAssertTrue(webView.waitForExistence(timeout: 3))
        
        let navBar = app.otherElements["WebNavigationBar"]
        XCTAssertTrue(navBar.staticTexts["Uniswap"].exists)
        
        screenshots.captureScreen(named: "DeepLink_SpecificApp")
    }
    
    func testDeepLinkToTransaction() {
        // Launch with wallet user
        UITestMockDataProvider.configure(app: app, for: .walletUser)
        app.launch()
        app.terminate()
        
        // Open deep link to specific transaction
        safari.launch()
        let urlBar = safari.otherElements["URL"]
        urlBar.tap()
        urlBar.typeText("interspace://transaction/0x123abc")
        safari.buttons["Go"].tap()
        
        // Open in app
        if safari.buttons["Open"].waitForExistence(timeout: 3) {
            safari.buttons["Open"].tap()
        }
        
        // Verify transaction detail view opens
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        let detailView = app.otherElements[AccessibilityIdentifiers.Transaction.transactionDetail]
        XCTAssertTrue(detailView.waitForExistence(timeout: 3))
        
        XCTAssertTrue(app.staticTexts["0x123...abc"].exists)
        
        screenshots.captureScreen(named: "DeepLink_Transaction")
    }
    
    // MARK: - Authentication Deep Links
    
    func testDeepLinkRequiringAuth() {
        // Ensure app is logged out
        app.launch()
        
        // Navigate to settings and logout if needed
        if app.tabBars.firstMatch.exists {
            UITestHelpers.navigateToTab(.profile, in: app)
            app.buttons[AccessibilityIdentifiers.Navigation.settingsButton].tap()
            
            let tableView = app.tables.firstMatch
            tableView.swipeUp()
            
            if app.buttons[AccessibilityIdentifiers.Settings.logoutButton].exists {
                app.buttons[AccessibilityIdentifiers.Settings.logoutButton].tap()
                app.alerts["Log Out"].buttons["Log Out"].tap()
            }
        }
        
        app.terminate()
        
        // Try to open protected deep link
        safari.launch()
        let urlBar = safari.otherElements["URL"]
        urlBar.tap()
        urlBar.typeText("interspace://profile/settings")
        safari.buttons["Go"].tap()
        
        // Open in app
        if safari.buttons["Open"].waitForExistence(timeout: 3) {
            safari.buttons["Open"].tap()
        }
        
        // Verify redirected to auth screen
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        let authTitle = app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle]
        XCTAssertTrue(authTitle.waitForExistence(timeout: 3))
        
        // Verify deep link is preserved (shown after auth)
        XCTAssertTrue(app.staticTexts["Sign in to continue to settings"].exists)
        
        screenshots.captureScreen(named: "DeepLink_RequiresAuth")
    }
    
    func testDeepLinkAfterAuthentication() {
        // Start logged out with pending deep link
        app.launch()
        app.terminate()
        
        // Set pending deep link
        safari.launch()
        let urlBar = safari.otherElements["URL"]
        urlBar.tap()
        urlBar.typeText("interspace://profile/settings")
        safari.buttons["Go"].tap()
        
        if safari.buttons["Open"].waitForExistence(timeout: 3) {
            safari.buttons["Open"].tap()
        }
        
        // Complete authentication
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        UITestHelpers.performEmailLogin(email: "test@example.com", code: "123456", in: app)
        
        // Verify deep link destination is reached after auth
        let settingsView = app.otherElements[AccessibilityIdentifiers.Settings.settingsView]
        XCTAssertTrue(settingsView.waitForExistence(timeout: 5))
        
        screenshots.captureScreen(named: "DeepLink_AfterAuth")
    }
    
    // MARK: - WalletConnect Deep Links
    
    func testWalletConnectDeepLink() {
        // Launch with authenticated user
        UITestMockDataProvider.configure(app: app, for: .returningUser)
        app.launch()
        app.terminate()
        
        // Open WalletConnect deep link
        safari.launch()
        let urlBar = safari.otherElements["URL"]
        urlBar.tap()
        urlBar.typeText("interspace://wc?uri=wc:abc123...")
        safari.buttons["Go"].tap()
        
        // Open in app
        if safari.buttons["Open"].waitForExistence(timeout: 3) {
            safari.buttons["Open"].tap()
        }
        
        // Verify WalletConnect modal opens
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        let wcModal = app.otherElements["WalletConnectModal"]
        XCTAssertTrue(wcModal.waitForExistence(timeout: 3))
        
        XCTAssertTrue(app.staticTexts["Connect to DApp"].exists)
        XCTAssertTrue(app.buttons["Connect"].exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
        
        screenshots.captureScreen(named: "DeepLink_WalletConnect")
    }
    
    // MARK: - Profile Switching Deep Links
    
    func testDeepLinkToSpecificProfile() {
        // Launch with multi-profile user
        UITestMockDataProvider.configure(app: app, for: .multiProfile)
        app.launch()
        app.terminate()
        
        // Open deep link to specific profile
        safari.launch()
        let urlBar = safari.otherElements["URL"]
        urlBar.tap()
        urlBar.typeText("interspace://profile/switch/gaming")
        safari.buttons["Go"].tap()
        
        // Open in app
        if safari.buttons["Open"].waitForExistence(timeout: 3) {
            safari.buttons["Open"].tap()
        }
        
        // Verify profile switched
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        // Check profile indicator
        UITestHelpers.navigateToTab(.profile, in: app)
        XCTAssertTrue(app.staticTexts["Gaming"].waitForExistence(timeout: 3))
        
        screenshots.captureScreen(named: "DeepLink_ProfileSwitch")
    }
    
    // MARK: - Invalid Deep Link Tests
    
    func testInvalidDeepLink() {
        // Launch app
        app.launch()
        app.terminate()
        
        // Try invalid deep link
        safari.launch()
        let urlBar = safari.otherElements["URL"]
        urlBar.tap()
        urlBar.typeText("interspace://invalid/path")
        safari.buttons["Go"].tap()
        
        // Open in app
        if safari.buttons["Open"].waitForExistence(timeout: 3) {
            safari.buttons["Open"].tap()
        }
        
        // Verify app handles gracefully
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        // Should show error or default to home
        let errorAlert = app.alerts["Invalid Link"]
        if errorAlert.waitForExistence(timeout: 2) {
            XCTAssertTrue(errorAlert.staticTexts["The link you followed is invalid"].exists)
            errorAlert.buttons["OK"].tap()
        }
        
        // Verify on home tab
        let homeTab = app.tabBars.buttons[AccessibilityIdentifiers.Navigation.homeTab]
        XCTAssertTrue(homeTab.isSelected)
        
        screenshots.captureScreen(named: "DeepLink_Invalid")
    }
    
    // MARK: - Universal Links Tests
    
    func testUniversalLink() {
        // Launch app
        app.launch()
        app.terminate()
        
        // Open universal link
        safari.launch()
        let urlBar = safari.otherElements["URL"]
        urlBar.tap()
        urlBar.typeText("https://interspace.app/profile")
        safari.buttons["Go"].tap()
        
        // App should auto-open (in real device)
        // In simulator, we simulate the behavior
        Thread.sleep(forTimeInterval: 1)
        
        // Verify app opens
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        let profileTab = app.tabBars.buttons[AccessibilityIdentifiers.Navigation.profileTab]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 3))
        
        screenshots.captureScreen(named: "UniversalLink_Profile")
    }
    
    // MARK: - Share Extension Deep Links
    
    func testShareToInterspace() {
        // This test simulates sharing content to Interspace
        // Open Safari with a DeFi app
        safari.launch()
        let urlBar = safari.otherElements["URL"]
        urlBar.tap()
        urlBar.typeText("https://app.uniswap.org")
        safari.buttons["Go"].tap()
        
        // Wait for page to load
        Thread.sleep(forTimeInterval: 2)
        
        // Open share sheet
        safari.buttons["Share"].tap()
        
        // Look for Interspace in share sheet
        let shareSheet = safari.otherElements["ActivityListView"]
        if shareSheet.waitForExistence(timeout: 2) {
            // Scroll to find Interspace if needed
            shareSheet.swipeLeft()
            
            let interspaceShareButton = safari.buttons["Interspace"]
            if interspaceShareButton.exists {
                interspaceShareButton.tap()
                
                // Verify Interspace opens with shared content
                XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
                
                // Should show add app modal
                let addAppModal = app.otherElements["AddAppFromShare"]
                XCTAssertTrue(addAppModal.waitForExistence(timeout: 3))
                
                screenshots.captureScreen(named: "ShareExtension_AddApp")
            }
        }
    }
    
    // MARK: - Background Deep Link Tests
    
    func testDeepLinkFromBackground() {
        // Launch app
        UITestMockDataProvider.configure(app: app, for: .returningUser)
        app.launch()
        
        // Send to background
        XCUIDevice.shared.press(.home)
        
        // Open deep link
        safari.activate()
        let urlBar = safari.otherElements["URL"]
        urlBar.tap()
        urlBar.typeText("interspace://wallet/send")
        safari.buttons["Go"].tap()
        
        // Open in app
        if safari.buttons["Open"].waitForExistence(timeout: 3) {
            safari.buttons["Open"].tap()
        }
        
        // Verify app comes to foreground with correct view
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        let sendSheet = app.sheets["Send Token"]
        XCTAssertTrue(sendSheet.waitForExistence(timeout: 3))
        
        screenshots.captureScreen(named: "DeepLink_FromBackground")
    }
}