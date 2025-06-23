import XCTest

// MARK: - UI Test Helpers

class UITestHelpers {
    
    // MARK: - Navigation Helpers
    
    static func navigateToTab(_ tab: Tab, in app: XCUIApplication) {
        let tabButton = app.tabBars.buttons[tab.rawValue]
        if !tabButton.isSelected {
            tabButton.tap()
        }
    }
    
    static func dismissKeyboard(in app: XCUIApplication) {
        if app.keyboards.element.exists {
            app.toolbars["Toolbar"].buttons["Done"].tap()
        }
    }
    
    // MARK: - Authentication Helpers
    
    static func performEmailLogin(email: String, code: String, in app: XCUIApplication) {
        app.buttons["Continue with Email"].tap()
        
        let emailTextField = app.textFields["Email"]
        XCTAssertTrue(emailTextField.waitForExistence(timeout: 2))
        emailTextField.tap()
        emailTextField.typeText(email)
        
        app.buttons["Send Code"].tap()
        
        let codeTextField = app.textFields["Verification Code"]
        XCTAssertTrue(codeTextField.waitForExistence(timeout: 2))
        codeTextField.tap()
        codeTextField.typeText(code)
        
        app.buttons["Verify"].tap()
    }
    
    static func performGoogleSignIn(in app: XCUIApplication) {
        app.buttons["Continue with Google"].tap()
        
        // In UI tests, we simulate the Google Sign In flow
        let mockGoogleWebView = app.webViews.firstMatch
        if mockGoogleWebView.waitForExistence(timeout: 2) {
            // Simulate successful Google sign in
            app.buttons["MockGoogleSignInSuccess"].tap()
        }
    }
    
    static func performAppleSignIn(in app: XCUIApplication) {
        app.buttons["Continue with Apple"].tap()
        
        // Handle Apple Sign In authorization sheet
        let authorizationSheet = app.sheets.firstMatch
        if authorizationSheet.waitForExistence(timeout: 2) {
            authorizationSheet.buttons["Continue"].tap()
        }
    }
    
    static func connectWallet(type: WalletType, in app: XCUIApplication) {
        app.buttons["Connect Wallet"].tap()
        
        let walletTray = app.otherElements["WalletSelectionTray"]
        XCTAssertTrue(walletTray.waitForExistence(timeout: 2))
        
        app.buttons[type.displayName].tap()
    }
    
    // MARK: - Profile Helpers
    
    static func createProfile(name: String, icon: String? = nil, color: String? = nil, in app: XCUIApplication) {
        let profileNameField = app.textFields["Profile name"]
        profileNameField.tap()
        profileNameField.typeText(name)
        
        if let icon = icon {
            app.buttons["SelectIcon"].tap()
            app.buttons[icon].tap()
        }
        
        if let color = color {
            app.buttons["SelectColor"].tap()
            app.buttons[color].tap()
        }
        
        app.buttons["Create Profile"].tap()
    }
    
    static func switchToProfile(named profileName: String, in app: XCUIApplication) {
        navigateToTab(.profile, in: app)
        
        app.buttons["ProfileSwitcher"].tap()
        
        let profileList = app.collectionViews["ProfileList"]
        XCTAssertTrue(profileList.waitForExistence(timeout: 2))
        
        profileList.cells.staticTexts[profileName].tap()
    }
    
    // MARK: - Wait Helpers
    
    static func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
    
    static func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    static func waitForMainInterface(in app: XCUIApplication) -> Bool {
        let tabBar = app.tabBars.firstMatch
        return waitForElement(tabBar)
    }
    
    // MARK: - Assertion Helpers
    
    static func assertElementExists(_ element: XCUIElement, message: String? = nil) {
        if let message = message {
            XCTAssertTrue(element.exists, message)
        } else {
            XCTAssertTrue(element.exists)
        }
    }
    
    static func assertElementNotExists(_ element: XCUIElement, message: String? = nil) {
        if let message = message {
            XCTAssertFalse(element.exists, message)
        } else {
            XCTAssertFalse(element.exists)
        }
    }
    
    static func assertTextExists(_ text: String, in app: XCUIApplication) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let element = app.staticTexts.containing(predicate).element
        XCTAssertTrue(element.exists, "Text '\(text)' should exist")
    }
    
    // MARK: - Screenshot Helpers
    
    static func takeScreenshot(named name: String, for testCase: XCTestCase) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
    }
    
    static func takeFailureScreenshot(for testCase: XCTestCase) {
        takeScreenshot(named: "Failure_\(Date().timeIntervalSince1970)", for: testCase)
    }
    
    // MARK: - Swipe and Scroll Helpers
    
    static func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement, maxSwipes: Int = 10) {
        var swipeCount = 0
        while !element.isHittable && swipeCount < maxSwipes {
            scrollView.swipeUp()
            swipeCount += 1
        }
    }
    
    static func pullToRefresh(in scrollView: XCUIElement) {
        let startCoordinate = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let endCoordinate = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        startCoordinate.press(forDuration: 0.1, thenDragTo: endCoordinate)
    }
}

// MARK: - Tab Enum

enum Tab: String {
    case home = "Home"
    case apps = "Apps"
    case wallet = "Wallet"
    case profile = "Profile"
}

// MARK: - Wallet Type Extension

enum WalletType {
    case metamask
    case coinbase
    case walletConnect
    
    var displayName: String {
        switch self {
        case .metamask:
            return "MetaMask"
        case .coinbase:
            return "Coinbase Wallet"
        case .walletConnect:
            return "WalletConnect"
        }
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and type text into a non string value")
            return
        }
        
        self.tap()
        
        // Select all and delete
        if stringValue.count > 0 {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
            self.typeText(deleteString)
        }
        
        self.typeText(text)
    }
    
    func waitAndTap(timeout: TimeInterval = 5) {
        XCTAssertTrue(self.waitForExistence(timeout: timeout))
        self.tap()
    }
    
    var isVisible: Bool {
        return exists && isHittable
    }
}

// MARK: - Accessibility Helpers

extension UITestHelpers {
    static func verifyAccessibility(for element: XCUIElement, expectedLabel: String? = nil, expectedHint: String? = nil) {
        XCTAssertTrue(element.exists, "Element should exist for accessibility verification")
        
        if let expectedLabel = expectedLabel {
            XCTAssertEqual(element.label, expectedLabel, "Accessibility label should match")
        }
        
        if let expectedHint = expectedHint {
            XCTAssertEqual(element.accessibilityHint, expectedHint, "Accessibility hint should match")
        }
        
        // Verify the element is accessible
        XCTAssertTrue(element.isAccessibilityElement, "Element should be accessible")
    }
    
    static func simulateVoiceOverSwipe(in app: XCUIApplication) {
        // Simulate VoiceOver navigation
        app.swipeRight()
    }
}

// MARK: - Network Condition Simulation

extension UITestHelpers {
    static func simulateOfflineMode(in app: XCUIApplication) {
        // This would typically be handled by launch arguments
        app.launchArguments.append("--offline-mode")
    }
    
    static func simulateSlowNetwork(in app: XCUIApplication) {
        app.launchArguments.append("--slow-network")
    }
}

// MARK: - Deep Link Helpers

extension UITestHelpers {
    static func openDeepLink(_ url: String, in app: XCUIApplication) {
        // Terminate and relaunch with URL
        app.terminate()
        
        // Use Safari to open the deep link
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()
        
        // Navigate to URL
        let urlBar = safari.otherElements["URL"]
        urlBar.tap()
        urlBar.typeText(url)
        safari.buttons["Go"].tap()
        
        // Handle app open prompt
        let openButton = safari.buttons["Open"]
        if openButton.waitForExistence(timeout: 5) {
            openButton.tap()
        }
    }
}