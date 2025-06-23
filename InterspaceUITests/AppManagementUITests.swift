import XCTest

class AppManagementUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        UITestMockDataProvider.configure(app: app, for: .returningUser)
        app.launchEnvironment["MOCK_APPS"] = "true"
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Apps Tab Tests
    
    func testAppsTabDisplay() {
        // Navigate to apps tab
        UITestHelpers.navigateToTab(.apps, in: app)
        
        // Verify apps grid is displayed
        let appsGrid = app.collectionViews[AccessibilityIdentifiers.Apps.appGrid]
        XCTAssertTrue(appsGrid.waitForExistence(timeout: 2))
        
        // Verify navigation bar
        XCTAssertTrue(app.navigationBars["Apps"].exists)
        
        // Verify add app button
        let addAppButton = app.buttons[AccessibilityIdentifiers.Apps.addAppButton]
        XCTAssertTrue(addAppButton.exists)
        
        screenshots.captureScreen(named: "Apps_Tab")
    }
    
    func testAppGridLayout() {
        // Navigate to apps tab
        UITestHelpers.navigateToTab(.apps, in: app)
        
        let appsGrid = app.collectionViews[AccessibilityIdentifiers.Apps.appGrid]
        
        // Verify mock apps are displayed
        let uniswapCell = appsGrid.cells["app_Uniswap"]
        let openseaCell = appsGrid.cells["app_OpenSea"]
        let aaveCell = appsGrid.cells["app_Aave"]
        let axieCell = appsGrid.cells["app_Axie Infinity"]
        
        XCTAssertTrue(uniswapCell.exists)
        XCTAssertTrue(openseaCell.exists)
        XCTAssertTrue(aaveCell.exists)
        XCTAssertTrue(axieCell.exists)
        
        // Verify app icons and names
        XCTAssertTrue(uniswapCell.staticTexts["🦄"].exists)
        XCTAssertTrue(uniswapCell.staticTexts["Uniswap"].exists)
        
        XCTAssertTrue(openseaCell.staticTexts["⛵"].exists)
        XCTAssertTrue(openseaCell.staticTexts["OpenSea"].exists)
        
        screenshots.captureScreen(named: "Apps_Grid")
    }
    
    func testAppSearch() {
        // Navigate to apps tab
        UITestHelpers.navigateToTab(.apps, in: app)
        
        // Tap search bar
        let searchBar = app.searchFields[AccessibilityIdentifiers.Apps.searchBar]
        XCTAssertTrue(searchBar.exists)
        searchBar.tap()
        
        // Search for specific app
        searchBar.typeText("Uniswap")
        
        // Verify filtered results
        let appsGrid = app.collectionViews[AccessibilityIdentifiers.Apps.appGrid]
        XCTAssertTrue(appsGrid.cells["app_Uniswap"].exists)
        XCTAssertFalse(appsGrid.cells["app_OpenSea"].exists)
        XCTAssertFalse(appsGrid.cells["app_Aave"].exists)
        
        screenshots.captureScreen(named: "App_Search")
        
        // Clear search
        searchBar.buttons["Clear text"].tap()
        
        // Verify all apps shown again
        XCTAssertTrue(appsGrid.cells["app_OpenSea"].waitForExistence(timeout: 1))
        XCTAssertTrue(appsGrid.cells["app_Aave"].exists)
    }
    
    func testAppCategoryFilter() {
        // Navigate to apps tab
        UITestHelpers.navigateToTab(.apps, in: app)
        
        // Tap category filter
        let categoryFilter = app.buttons[AccessibilityIdentifiers.Apps.categoryFilter]
        XCTAssertTrue(categoryFilter.exists)
        categoryFilter.tap()
        
        // Verify category options
        let filterSheet = app.sheets["Filter by Category"]
        XCTAssertTrue(filterSheet.waitForExistence(timeout: 2))
        
        XCTAssertTrue(filterSheet.buttons["All"].exists)
        XCTAssertTrue(filterSheet.buttons["DeFi"].exists)
        XCTAssertTrue(filterSheet.buttons["NFT"].exists)
        XCTAssertTrue(filterSheet.buttons["Gaming"].exists)
        XCTAssertTrue(filterSheet.buttons["Social"].exists)
        
        // Select DeFi category
        filterSheet.buttons["DeFi"].tap()
        
        // Verify filtered apps
        let appsGrid = app.collectionViews[AccessibilityIdentifiers.Apps.appGrid]
        XCTAssertTrue(appsGrid.cells["app_Uniswap"].exists)
        XCTAssertTrue(appsGrid.cells["app_Aave"].exists)
        XCTAssertFalse(appsGrid.cells["app_OpenSea"].exists)
        XCTAssertFalse(appsGrid.cells["app_Axie Infinity"].exists)
        
        // Verify filter indicator
        XCTAssertTrue(app.staticTexts["DeFi"].exists)
        
        screenshots.captureScreen(named: "Apps_Filtered_DeFi")
    }
    
    // MARK: - Add App Tests
    
    func testAddAppFlow() {
        // Navigate to apps tab
        UITestHelpers.navigateToTab(.apps, in: app)
        
        // Tap add app button
        let addAppButton = app.buttons[AccessibilityIdentifiers.Apps.addAppButton]
        addAppButton.tap()
        
        // Verify add app view
        let addAppView = app.otherElements["AddAppView"]
        XCTAssertTrue(addAppView.waitForExistence(timeout: 2))
        
        // Verify popular apps section
        XCTAssertTrue(app.staticTexts["Popular Apps"].exists)
        
        let popularAppsList = app.tables["PopularAppsList"]
        XCTAssertTrue(popularAppsList.exists)
        
        // Select a popular app
        let compoundCell = popularAppsList.cells["app_Compound"]
        XCTAssertTrue(compoundCell.waitForExistence(timeout: 1))
        compoundCell.tap()
        
        // Verify app preview
        let appPreview = app.otherElements["AppPreview"]
        XCTAssertTrue(appPreview.waitForExistence(timeout: 2))
        
        XCTAssertTrue(app.staticTexts["Compound"].exists)
        XCTAssertTrue(app.staticTexts["Lending & Borrowing Protocol"].exists)
        XCTAssertTrue(app.images["compound_preview"].exists)
        
        screenshots.captureScreen(named: "Add_App_Preview")
        
        // Add the app
        let addButton = app.buttons["Add to Home"]
        XCTAssertTrue(addButton.exists)
        addButton.tap()
        
        // Verify app added confirmation
        XCTAssertTrue(app.staticTexts["App Added"].waitForExistence(timeout: 1))
        
        // Verify returned to apps grid
        let appsGrid = app.collectionViews[AccessibilityIdentifiers.Apps.appGrid]
        XCTAssertTrue(appsGrid.waitForExistence(timeout: 2))
        XCTAssertTrue(appsGrid.cells["app_Compound"].exists)
    }
    
    func testAddCustomApp() {
        // Navigate to apps tab
        UITestHelpers.navigateToTab(.apps, in: app)
        
        // Add app
        app.buttons[AccessibilityIdentifiers.Apps.addAppButton].tap()
        
        // Switch to custom tab
        let customTab = app.buttons["Custom"]
        XCTAssertTrue(customTab.waitForExistence(timeout: 2))
        customTab.tap()
        
        // Enter custom app URL
        let urlField = app.textFields["App URL"]
        XCTAssertTrue(urlField.exists)
        urlField.tap()
        urlField.typeText("https://custom-defi-app.com")
        
        // Fetch app info
        app.buttons["Fetch Info"].tap()
        
        // Mock fetched info
        XCTAssertTrue(app.staticTexts["Custom DeFi App"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.images["fetched_app_icon"].exists)
        
        // Add custom app
        app.buttons["Add App"].tap()
        
        // Verify added
        XCTAssertTrue(app.staticTexts["App Added"].waitForExistence(timeout: 1))
        
        screenshots.captureScreen(named: "Custom_App_Added")
    }
    
    // MARK: - App Interaction Tests
    
    func testOpenApp() {
        // Navigate to apps tab
        UITestHelpers.navigateToTab(.apps, in: app)
        
        // Tap on an app
        let appsGrid = app.collectionViews[AccessibilityIdentifiers.Apps.appGrid]
        let uniswapCell = appsGrid.cells["app_Uniswap"]
        uniswapCell.tap()
        
        // Verify web browser view opens
        let webView = app.webViews[AccessibilityIdentifiers.Apps.appWebView]
        XCTAssertTrue(webView.waitForExistence(timeout: 3))
        
        // Verify navigation bar
        let navBar = app.otherElements["WebNavigationBar"]
        XCTAssertTrue(navBar.exists)
        XCTAssertTrue(navBar.staticTexts["Uniswap"].exists)
        
        // Verify browser controls
        XCTAssertTrue(app.buttons["Back"].exists)
        XCTAssertTrue(app.buttons["Forward"].exists)
        XCTAssertTrue(app.buttons["Refresh"].exists)
        XCTAssertTrue(app.buttons["Share"].exists)
        XCTAssertTrue(app.buttons["Done"].exists)
        
        screenshots.captureScreen(named: "App_WebView")
    }
    
    func testAppLongPress() {
        // Navigate to apps tab
        UITestHelpers.navigateToTab(.apps, in: app)
        
        let appsGrid = app.collectionViews[AccessibilityIdentifiers.Apps.appGrid]
        let uniswapCell = appsGrid.cells["app_Uniswap"]
        
        // Long press for context menu
        uniswapCell.press(forDuration: 1.0)
        
        // Verify context menu
        let contextMenu = app.otherElements["AppContextMenu"]
        XCTAssertTrue(contextMenu.waitForExistence(timeout: 2))
        
        XCTAssertTrue(app.buttons["Open"].exists)
        XCTAssertTrue(app.buttons["Share"].exists)
        XCTAssertTrue(app.buttons["Move to Folder"].exists)
        XCTAssertTrue(app.buttons["Remove from Home"].exists)
        
        screenshots.captureScreen(named: "App_ContextMenu")
        
        // Test remove action
        app.buttons["Remove from Home"].tap()
        
        // Verify confirmation
        let confirmAlert = app.alerts["Remove App"]
        XCTAssertTrue(confirmAlert.waitForExistence(timeout: 1))
        XCTAssertTrue(confirmAlert.staticTexts["Remove Uniswap from your home screen?"].exists)
        
        confirmAlert.buttons["Remove"].tap()
        
        // Verify app removed
        XCTAssertFalse(uniswapCell.exists)
    }
    
    // MARK: - App Organization Tests
    
    func testCreateAppFolder() {
        // Navigate to apps tab
        UITestHelpers.navigateToTab(.apps, in: app)
        
        let appsGrid = app.collectionViews[AccessibilityIdentifiers.Apps.appGrid]
        
        // Enter edit mode
        let editButton = app.buttons["Edit"]
        XCTAssertTrue(editButton.exists)
        editButton.tap()
        
        // Verify edit mode
        XCTAssertTrue(app.staticTexts["Tap and hold to move apps"].waitForExistence(timeout: 1))
        
        // Drag one app onto another
        let uniswapCell = appsGrid.cells["app_Uniswap"]
        let aaveCell = appsGrid.cells["app_Aave"]
        
        uniswapCell.press(forDuration: 0.5, thenDragTo: aaveCell)
        
        // Verify folder creation prompt
        let folderNameField = app.textFields["Folder Name"]
        XCTAssertTrue(folderNameField.waitForExistence(timeout: 2))
        
        // Name the folder
        folderNameField.tap()
        folderNameField.typeText("DeFi Apps")
        
        app.buttons["Create Folder"].tap()
        
        // Exit edit mode
        app.buttons["Done"].tap()
        
        // Verify folder created
        let folderCell = appsGrid.cells["folder_DeFi Apps"]
        XCTAssertTrue(folderCell.waitForExistence(timeout: 2))
        XCTAssertTrue(folderCell.staticTexts["DeFi Apps"].exists)
        XCTAssertTrue(folderCell.staticTexts["2 apps"].exists)
        
        screenshots.captureScreen(named: "App_Folder_Created")
    }
    
    func testOpenAppFolder() {
        // Create folder first
        testCreateAppFolder()
        
        let appsGrid = app.collectionViews[AccessibilityIdentifiers.Apps.appGrid]
        let folderCell = appsGrid.cells["folder_DeFi Apps"]
        
        // Open folder
        folderCell.tap()
        
        // Verify folder view
        let folderView = app.otherElements["AppFolderView"]
        XCTAssertTrue(folderView.waitForExistence(timeout: 2))
        
        XCTAssertTrue(app.navigationBars["DeFi Apps"].exists)
        
        // Verify apps in folder
        let folderGrid = folderView.collectionViews.firstMatch
        XCTAssertTrue(folderGrid.cells["app_Uniswap"].exists)
        XCTAssertTrue(folderGrid.cells["app_Aave"].exists)
        
        screenshots.captureScreen(named: "App_Folder_Open")
        
        // Test opening app from folder
        folderGrid.cells["app_Uniswap"].tap()
        
        let webView = app.webViews[AccessibilityIdentifiers.Apps.appWebView]
        XCTAssertTrue(webView.waitForExistence(timeout: 3))
    }
    
    // MARK: - App Sync Tests
    
    func testAppSyncAcrossProfiles() {
        // Navigate to apps tab
        UITestHelpers.navigateToTab(.apps, in: app)
        
        // Verify initial apps
        let appsGrid = app.collectionViews[AccessibilityIdentifiers.Apps.appGrid]
        XCTAssertTrue(appsGrid.cells["app_Uniswap"].exists)
        
        // Switch profile
        UITestHelpers.switchToProfile(named: "Gaming", in: app)
        
        // Navigate back to apps
        UITestHelpers.navigateToTab(.apps, in: app)
        
        // Verify different apps for gaming profile
        XCTAssertTrue(appsGrid.cells["app_Axie Infinity"].waitForExistence(timeout: 2))
        XCTAssertFalse(appsGrid.cells["app_Uniswap"].exists)
        
        screenshots.captureScreen(named: "Apps_Gaming_Profile")
    }
    
    // MARK: - App Settings Tests
    
    func testAppSettings() {
        // Navigate to apps tab
        UITestHelpers.navigateToTab(.apps, in: app)
        
        // Open app settings
        app.buttons["App Settings"].tap()
        
        // Verify settings view
        let settingsView = app.otherElements["AppSettingsView"]
        XCTAssertTrue(settingsView.waitForExistence(timeout: 2))
        
        // Verify settings options
        XCTAssertTrue(app.switches["Auto-arrange apps"].exists)
        XCTAssertTrue(app.switches["Show app badges"].exists)
        XCTAssertTrue(app.switches["Enable app notifications"].exists)
        
        // Toggle a setting
        let autoArrangeSwitch = app.switches["Auto-arrange apps"]
        let initialValue = autoArrangeSwitch.value as? String == "1"
        autoArrangeSwitch.tap()
        
        // Verify toggle changed
        let newValue = autoArrangeSwitch.value as? String == "1"
        XCTAssertNotEqual(initialValue, newValue)
        
        screenshots.captureScreen(named: "App_Settings")
    }
}