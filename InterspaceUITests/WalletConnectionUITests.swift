import XCTest

class WalletConnectionUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launchEnvironment = [
            "MOCK_API": "true",
            "MOCK_WALLET_CONNECT": "true"
        ]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Wallet Connection Button Tests
    
    func testWalletConnectionButtonPresence() {
        // Wait for auth screen
        let authTitle = app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle]
        XCTAssertTrue(authTitle.waitForExistence(timeout: 5))
        
        // Verify Connect Wallet button
        let connectWalletButton = app.buttons[AccessibilityIdentifiers.Authentication.connectWalletButton]
        XCTAssertTrue(connectWalletButton.exists)
        XCTAssertTrue(connectWalletButton.isEnabled)
        
        // Verify accessibility
        UITestHelpers.verifyAccessibility(
            for: connectWalletButton,
            expectedLabel: AccessibilityLabels.Authentication.connectWallet,
            expectedHint: AccessibilityHints.Authentication.connectWallet
        )
        
        screenshots.captureScreen(named: "WalletConnect_Button")
    }
    
    func testWalletSelectionTray() {
        // Tap Connect Wallet button
        let connectWalletButton = app.buttons[AccessibilityIdentifiers.Authentication.connectWalletButton]
        connectWalletButton.tap()
        
        // Verify wallet selection tray appears
        let walletTray = app.otherElements[AccessibilityIdentifiers.Wallet.selectionTray]
        XCTAssertTrue(walletTray.waitForExistence(timeout: 2))
        
        // Verify wallet options
        let metamaskButton = app.buttons[AccessibilityIdentifiers.Wallet.metamaskButton]
        let coinbaseButton = app.buttons[AccessibilityIdentifiers.Wallet.coinbaseButton]
        let walletConnectButton = app.buttons[AccessibilityIdentifiers.Wallet.walletConnectButton]
        
        XCTAssertTrue(metamaskButton.exists)
        XCTAssertTrue(coinbaseButton.exists)
        XCTAssertTrue(walletConnectButton.exists)
        
        // Verify wallet icons
        XCTAssertTrue(app.images["metamask"].exists)
        XCTAssertTrue(app.images["coinbase"].exists)
        XCTAssertTrue(app.images["walletconnect"].exists)
        
        screenshots.captureScreen(named: "WalletSelectionTray")
    }
    
    // MARK: - MetaMask Connection Tests
    
    func testMetaMaskConnectionFlow() {
        // Open wallet selection
        app.buttons[AccessibilityIdentifiers.Authentication.connectWalletButton].tap()
        
        let walletTray = app.otherElements[AccessibilityIdentifiers.Wallet.selectionTray]
        XCTAssertTrue(walletTray.waitForExistence(timeout: 2))
        
        // Select MetaMask
        app.buttons[AccessibilityIdentifiers.Wallet.metamaskButton].tap()
        
        // Verify connecting state
        let connectingIndicator = app.progressIndicators[AccessibilityIdentifiers.Wallet.connectingIndicator]
        XCTAssertTrue(connectingIndicator.waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Connecting to MetaMask..."].exists)
        
        screenshots.captureScreen(named: "MetaMask_Connecting")
        
        // In mock mode, simulate MetaMask deep link response
        Thread.sleep(forTimeInterval: 1.5) // Simulate connection delay
        
        // Mock approval in MetaMask
        let mockApprovalAlert = app.alerts["MetaMask Connection"]
        if mockApprovalAlert.waitForExistence(timeout: 2) {
            XCTAssertTrue(mockApprovalAlert.staticTexts["Interspace wants to connect to your wallet"].exists)
            mockApprovalAlert.buttons["Connect"].tap()
        }
        
        // Verify successful connection
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        
        // Navigate to wallet tab
        UITestHelpers.navigateToTab(.wallet, in: app)
        
        // Verify wallet is connected
        let connectedStatus = app.staticTexts[AccessibilityIdentifiers.Wallet.connectedStatus]
        XCTAssertTrue(connectedStatus.waitForExistence(timeout: 2))
        
        // Verify wallet address is displayed
        let addressLabel = app.staticTexts[AccessibilityIdentifiers.Wallet.addressLabel]
        XCTAssertTrue(addressLabel.exists)
        XCTAssertTrue(addressLabel.label.contains("0x"))
        
        screenshots.captureScreen(named: "MetaMask_Connected")
    }
    
    func testMetaMaskConnectionRejection() {
        // Configure for rejection scenario
        app.terminate()
        app.launchEnvironment["WALLET_CONNECT_REJECT"] = "true"
        app.launch()
        
        // Open wallet selection
        app.buttons[AccessibilityIdentifiers.Authentication.connectWalletButton].tap()
        
        // Select MetaMask
        app.buttons[AccessibilityIdentifiers.Wallet.metamaskButton].tap()
        
        // Mock rejection in MetaMask
        let mockApprovalAlert = app.alerts["MetaMask Connection"]
        if mockApprovalAlert.waitForExistence(timeout: 2) {
            mockApprovalAlert.buttons["Cancel"].tap()
        }
        
        // Verify error message
        let errorAlert = app.alerts["Connection Failed"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(errorAlert.staticTexts["User rejected the connection request"].exists)
        
        screenshots.captureScreen(named: "MetaMask_Rejected")
        
        // Dismiss error
        errorAlert.buttons["OK"].tap()
        
        // Verify back at auth screen
        XCTAssertTrue(app.staticTexts[AccessibilityIdentifiers.Authentication.welcomeTitle].exists)
    }
    
    func testMetaMaskDeepLinkHandling() {
        // Test deep link URL handling for MetaMask
        app.buttons[AccessibilityIdentifiers.Authentication.connectWalletButton].tap()
        app.buttons[AccessibilityIdentifiers.Wallet.metamaskButton].tap()
        
        // Verify deep link is triggered (in mock mode)
        let deepLinkIndicator = app.otherElements["DeepLinkTriggered"]
        XCTAssertTrue(deepLinkIndicator.waitForExistence(timeout: 2))
        XCTAssertEqual(deepLinkIndicator.label, "metamask://connect")
    }
    
    // MARK: - Coinbase Wallet Tests
    
    func testCoinbaseWalletConnection() {
        // Open wallet selection
        app.buttons[AccessibilityIdentifiers.Authentication.connectWalletButton].tap()
        
        // Select Coinbase Wallet
        app.buttons[AccessibilityIdentifiers.Wallet.coinbaseButton].tap()
        
        // Verify connecting state
        XCTAssertTrue(app.staticTexts["Connecting to Coinbase Wallet..."].waitForExistence(timeout: 1))
        
        // Mock Coinbase connection
        Thread.sleep(forTimeInterval: 1.5)
        
        // Verify successful connection
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        
        // Verify wallet details
        UITestHelpers.navigateToTab(.wallet, in: app)
        XCTAssertTrue(app.staticTexts["Connected to Coinbase Wallet"].exists)
        
        screenshots.captureScreen(named: "Coinbase_Connected")
    }
    
    // MARK: - WalletConnect Tests
    
    func testWalletConnectQRCode() {
        // Open wallet selection
        app.buttons[AccessibilityIdentifiers.Authentication.connectWalletButton].tap()
        
        // Select WalletConnect
        app.buttons[AccessibilityIdentifiers.Wallet.walletConnectButton].tap()
        
        // Verify QR code modal appears
        let qrCodeModal = app.otherElements["WalletConnectQRModal"]
        XCTAssertTrue(qrCodeModal.waitForExistence(timeout: 2))
        
        // Verify QR code is displayed
        XCTAssertTrue(app.images["WalletConnectQRCode"].exists)
        XCTAssertTrue(app.staticTexts["Scan with your wallet app"].exists)
        
        // Verify copy button
        let copyButton = app.buttons["Copy to clipboard"]
        XCTAssertTrue(copyButton.exists)
        
        screenshots.captureScreen(named: "WalletConnect_QRCode")
        
        // Test copy functionality
        copyButton.tap()
        XCTAssertTrue(app.staticTexts["Copied!"].waitForExistence(timeout: 1))
    }
    
    func testWalletConnectWithMultipleWallets() {
        // Configure for multi-wallet scenario
        app.terminate()
        app.launchEnvironment["MULTI_WALLET_TEST"] = "true"
        app.launch()
        
        // Connect first wallet
        UITestHelpers.connectWallet(type: .metamask, in: app)
        
        // Navigate to wallet tab
        UITestHelpers.navigateToTab(.wallet, in: app)
        
        // Add another wallet
        app.buttons["Add Wallet"].tap()
        
        // Connect Coinbase wallet
        app.buttons[AccessibilityIdentifiers.Wallet.coinbaseButton].tap()
        Thread.sleep(forTimeInterval: 1.5)
        
        // Verify multiple wallets connected
        XCTAssertTrue(app.cells["wallet_0x742d...BEd4"].exists) // MetaMask
        XCTAssertTrue(app.cells["wallet_0x123d...BEd5"].exists) // Coinbase
        
        screenshots.captureScreen(named: "MultipleWallets")
    }
    
    // MARK: - Wallet Disconnection Tests
    
    func testWalletDisconnection() {
        // Start with connected wallet
        UITestMockDataProvider.configure(app: app, for: .walletUser)
        app.launch()
        
        // Navigate to wallet tab
        UITestHelpers.navigateToTab(.wallet, in: app)
        
        // Verify wallet is connected
        XCTAssertTrue(app.staticTexts[AccessibilityIdentifiers.Wallet.connectedStatus].exists)
        
        // Open wallet settings
        app.buttons["Wallet Settings"].tap()
        
        // Tap disconnect
        let disconnectButton = app.buttons[AccessibilityIdentifiers.Wallet.disconnectButton]
        XCTAssertTrue(disconnectButton.exists)
        disconnectButton.tap()
        
        // Confirm disconnection
        let confirmAlert = app.alerts["Disconnect Wallet"]
        XCTAssertTrue(confirmAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(confirmAlert.staticTexts["Are you sure you want to disconnect your wallet?"].exists)
        
        confirmAlert.buttons["Disconnect"].tap()
        
        // Verify wallet disconnected
        XCTAssertTrue(app.staticTexts["No wallet connected"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Connect Wallet"].exists)
        
        screenshots.captureScreen(named: "Wallet_Disconnected")
    }
    
    // MARK: - Wallet Error Scenarios
    
    func testWalletConnectionTimeout() {
        // Configure for timeout scenario
        app.terminate()
        app.launchEnvironment["WALLET_CONNECT_TIMEOUT"] = "true"
        app.launch()
        
        // Attempt wallet connection
        app.buttons[AccessibilityIdentifiers.Authentication.connectWalletButton].tap()
        app.buttons[AccessibilityIdentifiers.Wallet.metamaskButton].tap()
        
        // Wait for timeout (mocked to be faster)
        let timeoutAlert = app.alerts["Connection Timeout"]
        XCTAssertTrue(timeoutAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(timeoutAlert.staticTexts["Failed to connect to wallet. Please try again."].exists)
        
        // Retry option
        XCTAssertTrue(timeoutAlert.buttons["Retry"].exists)
        XCTAssertTrue(timeoutAlert.buttons["Cancel"].exists)
        
        screenshots.captureScreen(named: "Wallet_Timeout")
    }
    
    func testWalletNetworkMismatch() {
        // Configure for network mismatch
        app.terminate()
        app.launchEnvironment["WALLET_WRONG_NETWORK"] = "true"
        app.launch()
        
        // Connect wallet
        UITestHelpers.connectWallet(type: .metamask, in: app)
        
        // Verify network mismatch warning
        let networkAlert = app.alerts["Wrong Network"]
        XCTAssertTrue(networkAlert.waitForExistence(timeout: 3))
        XCTAssertTrue(networkAlert.staticTexts["Please switch to Ethereum Mainnet in your wallet"].exists)
        
        networkAlert.buttons["OK"].tap()
        
        // Verify network indicator shows warning
        UITestHelpers.navigateToTab(.wallet, in: app)
        XCTAssertTrue(app.staticTexts["Wrong Network"].exists)
        XCTAssertTrue(app.images["warning_icon"].exists)
        
        screenshots.captureScreen(named: "Wallet_NetworkMismatch")
    }
    
    // MARK: - Wallet Session Management
    
    func testWalletSessionPersistence() {
        // Connect wallet
        UITestHelpers.connectWallet(type: .metamask, in: app)
        
        // Verify connected
        UITestHelpers.navigateToTab(.wallet, in: app)
        XCTAssertTrue(app.staticTexts[AccessibilityIdentifiers.Wallet.connectedStatus].exists)
        
        // Force quit app
        app.terminate()
        
        // Relaunch
        app.launch()
        
        // Verify wallet still connected
        UITestHelpers.navigateToTab(.wallet, in: app)
        XCTAssertTrue(app.staticTexts[AccessibilityIdentifiers.Wallet.connectedStatus].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts[AccessibilityIdentifiers.Wallet.addressLabel].exists)
        
        screenshots.captureScreen(named: "Wallet_SessionPersisted")
    }
    
    func testWalletAutoReconnect() {
        // Start with connected wallet
        UITestMockDataProvider.configure(app: app, for: .walletUser)
        app.launch()
        
        // Simulate wallet disconnect event
        app.terminate()
        app.launchEnvironment["SIMULATE_WALLET_DISCONNECT"] = "true"
        app.launch()
        
        // Verify auto-reconnect attempt
        let reconnectingIndicator = app.progressIndicators["Reconnecting to wallet..."]
        XCTAssertTrue(reconnectingIndicator.waitForExistence(timeout: 3))
        
        // Verify reconnection success
        XCTAssertTrue(app.staticTexts[AccessibilityIdentifiers.Wallet.connectedStatus].waitForExistence(timeout: 5))
    }
    
    // MARK: - Wallet Integration Tests
    
    func testWalletSignatureRequest() {
        // Start with connected wallet
        UITestMockDataProvider.configure(app: app, for: .walletUser)
        app.launch()
        
        // Navigate to profile settings
        UITestHelpers.navigateToTab(.profile, in: app)
        app.buttons[AccessibilityIdentifiers.Profile.profileSettings].tap()
        
        // Trigger action requiring signature
        app.buttons["Verify Wallet Ownership"].tap()
        
        // Mock signature request
        let signatureAlert = app.alerts["Signature Request"]
        XCTAssertTrue(signatureAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(signatureAlert.staticTexts["Interspace requests your signature to verify wallet ownership"].exists)
        
        signatureAlert.buttons["Sign"].tap()
        
        // Verify success
        XCTAssertTrue(app.staticTexts["Wallet verified successfully"].waitForExistence(timeout: 2))
        
        screenshots.captureScreen(named: "Wallet_Signature_Success")
    }
}