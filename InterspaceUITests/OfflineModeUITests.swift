import XCTest

class OfflineModeUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        UITestMockDataProvider.configure(app: app, for: .offlineMode)
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Offline Indicator Tests
    
    func testOfflineIndicator() {
        // Verify offline indicator is shown
        let offlineIndicator = app.otherElements["OfflineIndicator"]
        XCTAssertTrue(offlineIndicator.waitForExistence(timeout: 3))
        
        // Verify indicator text
        XCTAssertTrue(app.staticTexts["No Internet Connection"].exists)
        
        // Verify indicator is visible across tabs
        UITestHelpers.navigateToTab(.apps, in: app)
        XCTAssertTrue(offlineIndicator.exists)
        
        UITestHelpers.navigateToTab(.wallet, in: app)
        XCTAssertTrue(offlineIndicator.exists)
        
        screenshots.captureScreen(named: "Offline_Indicator")
    }
    
    func testOfflineBanner() {
        // Some views might show a banner instead of persistent indicator
        UITestHelpers.navigateToTab(.home, in: app)
        
        let offlineBanner = app.otherElements["OfflineBanner"]
        if offlineBanner.exists {
            XCTAssertTrue(app.staticTexts["You're offline"].exists)
            XCTAssertTrue(app.staticTexts["Some features may be limited"].exists)
            
            // Test dismiss if available
            if app.buttons["Dismiss"].exists {
                app.buttons["Dismiss"].tap()
                XCTAssertFalse(offlineBanner.exists)
            }
        }
    }
    
    // MARK: - Authentication in Offline Mode
    
    func testOfflineAuthentication() {
        // Logout first if logged in
        if app.tabBars.firstMatch.exists {
            UITestHelpers.navigateToTab(.profile, in: app)
            app.buttons[AccessibilityIdentifiers.Navigation.settingsButton].tap()
            let tableView = app.tables.firstMatch
            tableView.swipeUp()
            app.buttons[AccessibilityIdentifiers.Settings.logoutButton].tap()
            app.alerts["Log Out"].buttons["Log Out"].tap()
        }
        
        // Try email authentication while offline
        app.buttons[AccessibilityIdentifiers.Authentication.emailButton].tap()
        
        let emailTextField = app.textFields["Email"]
        emailTextField.tap()
        emailTextField.typeText("test@example.com")
        
        app.buttons["Send Code"].tap()
        
        // Verify offline error
        let errorAlert = app.alerts["Connection Error"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(errorAlert.staticTexts["Unable to send verification code. Please check your internet connection."].exists)
        
        errorAlert.buttons["OK"].tap()
        
        screenshots.captureScreen(named: "Offline_Auth_Error")
    }
    
    func testOfflineGuestMode() {
        // Verify guest mode is available offline
        let guestButton = app.buttons[AccessibilityIdentifiers.Authentication.guestButton]
        XCTAssertTrue(guestButton.exists)
        XCTAssertTrue(guestButton.isEnabled)
        
        guestButton.tap()
        
        // Verify can access app in guest mode
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
        
        // Verify limited functionality message
        XCTAssertTrue(app.staticTexts["Limited functionality in offline mode"].waitForExistence(timeout: 2))
        
        screenshots.captureScreen(named: "Offline_Guest_Mode")
    }
    
    // MARK: - Cached Data Tests
    
    func testCachedProfileData() {
        // Start with cached user data
        app.terminate()
        UITestMockDataProvider.configure(app: app, for: .returningUser)
        app.launchEnvironment["CACHED_DATA"] = "true"
        app.launchEnvironment["NETWORK_STATE"] = "offline"
        app.launch()
        
        // Navigate to profile
        UITestHelpers.navigateToTab(.profile, in: app)
        
        // Verify cached profile data is displayed
        XCTAssertTrue(app.staticTexts["Main Profile"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["test@example.com"].exists)
        
        // Verify sync indicator
        XCTAssertTrue(app.images["sync_pending"].exists)
        XCTAssertTrue(app.staticTexts["Will sync when online"].exists)
        
        screenshots.captureScreen(named: "Offline_Cached_Profile")
    }
    
    func testCachedTransactionHistory() {
        // Configure with cached data
        app.terminate()
        UITestMockDataProvider.configure(app: app, for: .walletUser)
        app.launchEnvironment["CACHED_DATA"] = "true"
        app.launchEnvironment["NETWORK_STATE"] = "offline"
        app.launch()
        
        // Navigate to transaction history
        UITestHelpers.navigateToTab(.wallet, in: app)
        app.buttons[AccessibilityIdentifiers.Wallet.transactionHistory].tap()
        
        // Verify cached transactions are shown
        let transactionList = app.tables[AccessibilityIdentifiers.Transaction.historyList]
        XCTAssertTrue(transactionList.waitForExistence(timeout: 2))
        XCTAssertTrue(transactionList.cells.count > 0)
        
        // Verify offline notice
        XCTAssertTrue(app.staticTexts["Showing cached data"].exists)
        
        // Try to refresh
        UITestHelpers.pullToRefresh(in: transactionList)
        
        // Verify refresh fails gracefully
        XCTAssertTrue(app.staticTexts["Unable to refresh while offline"].waitForExistence(timeout: 2))
        
        screenshots.captureScreen(named: "Offline_Cached_Transactions")
    }
    
    // MARK: - Offline Functionality Tests
    
    func testOfflineAppBrowsing() {
        // Navigate to apps with cached data
        UITestHelpers.navigateToTab(.apps, in: app)
        
        let appsGrid = app.collectionViews[AccessibilityIdentifiers.Apps.appGrid]
        XCTAssertTrue(appsGrid.waitForExistence(timeout: 2))
        
        // Verify cached apps are displayed
        XCTAssertTrue(appsGrid.cells.count > 0)
        
        // Try to open an app
        appsGrid.cells.firstMatch.tap()
        
        // Verify offline error for web content
        let offlineAlert = app.alerts["Offline"]
        XCTAssertTrue(offlineAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(offlineAlert.staticTexts["This app requires an internet connection"].exists)
        
        offlineAlert.buttons["OK"].tap()
        
        screenshots.captureScreen(named: "Offline_App_Error")
    }
    
    func testOfflineWalletFeatures() {
        // Configure wallet user
        app.terminate()
        UITestMockDataProvider.configure(app: app, for: .walletUser)
        app.launchEnvironment["NETWORK_STATE"] = "offline"
        app.launch()
        
        // Navigate to wallet
        UITestHelpers.navigateToTab(.wallet, in: app)
        
        // Verify wallet address is shown (cached)
        XCTAssertTrue(app.staticTexts["0x742d...BEd4"].waitForExistence(timeout: 2))
        
        // Try to send transaction
        let sendButton = app.buttons[AccessibilityIdentifiers.Transaction.sendButton]
        sendButton.tap()
        
        // Verify offline warning
        let warningAlert = app.alerts["Offline Mode"]
        XCTAssertTrue(warningAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(warningAlert.staticTexts["Transactions cannot be sent while offline"].exists)
        
        warningAlert.buttons["OK"].tap()
        
        screenshots.captureScreen(named: "Offline_Wallet_Limited")
    }
    
    // MARK: - Offline to Online Transition Tests
    
    func testOfflineToOnlineTransition() {
        // Start offline
        XCTAssertTrue(app.otherElements["OfflineIndicator"].waitForExistence(timeout: 3))
        
        // Simulate network restoration
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "NETWORK_STATE")
        app.launch()
        
        // Verify offline indicator disappears
        let offlineIndicator = app.otherElements["OfflineIndicator"]
        XCTAssertTrue(UITestHelpers.waitForElementToDisappear(offlineIndicator, timeout: 5))
        
        // Verify sync starts
        let syncIndicator = app.progressIndicators["SyncingData"]
        if syncIndicator.waitForExistence(timeout: 2) {
            XCTAssertTrue(app.staticTexts["Syncing..."].exists)
            
            // Wait for sync to complete
            XCTAssertTrue(UITestHelpers.waitForElementToDisappear(syncIndicator, timeout: 10))
        }
        
        // Verify online functionality restored
        UITestHelpers.navigateToTab(.apps, in: app)
        let appsGrid = app.collectionViews[AccessibilityIdentifiers.Apps.appGrid]
        appsGrid.cells.firstMatch.tap()
        
        // Should open web view successfully
        let webView = app.webViews[AccessibilityIdentifiers.Apps.appWebView]
        XCTAssertTrue(webView.waitForExistence(timeout: 3))
        
        screenshots.captureScreen(named: "Online_Restored")
    }
    
    func testPendingActionsSync() {
        // Start offline with pending actions
        app.terminate()
        app.launchEnvironment["PENDING_ACTIONS"] = "true"
        app.launchEnvironment["NETWORK_STATE"] = "offline"
        app.launch()
        
        // Verify pending actions indicator
        UITestHelpers.navigateToTab(.profile, in: app)
        XCTAssertTrue(app.staticTexts["3 pending actions"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.images["pending_sync_icon"].exists)
        
        screenshots.captureScreen(named: "Offline_Pending_Actions")
        
        // Simulate going online
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "NETWORK_STATE")
        app.launch()
        
        // Verify pending actions sync
        UITestHelpers.navigateToTab(.profile, in: app)
        let syncNotification = app.otherElements["SyncNotification"]
        XCTAssertTrue(syncNotification.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Syncing 3 pending actions..."].exists)
        
        // Wait for sync completion
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(app.staticTexts["All actions synced successfully"].waitForExistence(timeout: 3))
        
        screenshots.captureScreen(named: "Pending_Actions_Synced")
    }
    
    // MARK: - Offline Settings Tests
    
    func testOfflineSettings() {
        // Navigate to settings
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Navigation.settingsButton].tap()
        
        // Verify limited settings in offline mode
        let tableView = app.tables.firstMatch
        
        // These should be available offline
        XCTAssertTrue(tableView.cells["Appearance"].exists)
        XCTAssertTrue(tableView.cells["Language"].exists)
        XCTAssertTrue(tableView.cells["About"].exists)
        
        // These should show offline indicators
        let privacyCell = tableView.cells["Privacy Settings"]
        privacyCell.tap()
        
        let offlineNotice = app.staticTexts["Some settings require internet connection"]
        XCTAssertTrue(offlineNotice.waitForExistence(timeout: 2))
        
        screenshots.captureScreen(named: "Offline_Settings")
    }
    
    // MARK: - Offline Error Handling Tests
    
    func testOfflineErrorMessages() {
        // Test various offline scenarios
        
        // 1. Try to add new app
        UITestHelpers.navigateToTab(.apps, in: app)
        app.buttons[AccessibilityIdentifiers.Apps.addAppButton].tap()
        
        let addAppError = app.alerts["Connection Required"]
        XCTAssertTrue(addAppError.waitForExistence(timeout: 2))
        XCTAssertTrue(addAppError.staticTexts["Adding apps requires an internet connection"].exists)
        addAppError.buttons["OK"].tap()
        
        // 2. Try to connect wallet
        UITestHelpers.navigateToTab(.wallet, in: app)
        if app.buttons["Connect Wallet"].exists {
            app.buttons["Connect Wallet"].tap()
            
            let walletError = app.alerts["Offline"]
            XCTAssertTrue(walletError.waitForExistence(timeout: 2))
            XCTAssertTrue(walletError.staticTexts["Wallet connection requires internet"].exists)
            walletError.buttons["OK"].tap()
        }
        
        screenshots.captureScreen(named: "Offline_Errors")
    }
    
    func testOfflineDataExpiration() {
        // Test cached data expiration notice
        app.terminate()
        app.launchEnvironment["EXPIRED_CACHE"] = "true"
        app.launchEnvironment["NETWORK_STATE"] = "offline"
        app.launch()
        
        // Should show stale data warning
        let staleDataBanner = app.otherElements["StaleDataBanner"]
        XCTAssertTrue(staleDataBanner.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Data last updated 7 days ago"].exists)
        
        screenshots.captureScreen(named: "Offline_Stale_Data")
    }
}