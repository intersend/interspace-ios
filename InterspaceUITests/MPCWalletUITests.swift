import XCTest

// MARK: - MPC Wallet UI Tests
// These tests verify the MPC wallet user interface and flows

final class MPCWalletUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--enable-mpc"]
        app.launchEnvironment = [
            "API_BASE_URL": "http://localhost:3000",
            "ENABLE_MPC": "true"
        ]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Test Cases
    
    /// Test creating a new profile with MPC wallet
    func testCreateProfileWithMPCWallet() throws {
        // Navigate to profile creation
        let createProfileButton = app.buttons["Create New Profile"]
        XCTAssertTrue(createProfileButton.waitForExistence(timeout: 5))
        createProfileButton.tap()
        
        // Enter profile name
        let profileNameField = app.textFields["profileNameField"]
        profileNameField.tap()
        profileNameField.typeText("Test MPC Profile")
        
        // Enable MPC wallet toggle (if exists)
        let mpcToggle = app.switches["enableMPCWallet"]
        if mpcToggle.exists {
            mpcToggle.tap()
        }
        
        // Create profile
        app.buttons["createProfileButton"].tap()
        
        // Wait for loading indicator
        let loadingIndicator = app.activityIndicators["mpcGeneratingWallet"]
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: 2))
        
        // Wait for wallet generation to complete
        let walletAddressLabel = app.staticTexts["walletAddress"]
        XCTAssertTrue(walletAddressLabel.waitForExistence(timeout: 30))
        
        // Verify wallet address format
        let address = walletAddressLabel.label
        XCTAssertTrue(address.hasPrefix("0x"))
        XCTAssertEqual(address.count, 42)
        
        // Take screenshot for documentation
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "MPC_Wallet_Created"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    /// Test signing a transaction with MPC wallet
    func testSignTransactionWithMPC() throws {
        // Assume we're already in a profile with MPC wallet
        navigateToProfileWithMPCWallet()
        
        // Navigate to send transaction
        app.tabBars.buttons["Wallet"].tap()
        app.buttons["Send"].tap()
        
        // Fill transaction details
        let recipientField = app.textFields["recipientAddress"]
        recipientField.tap()
        recipientField.typeText("0x742d35Cc6634C0532925a3b844Bc9e7595f8150")
        
        let amountField = app.textFields["amount"]
        amountField.tap()
        amountField.typeText("0.001")
        
        // Continue to signing
        app.buttons["Review"].tap()
        
        // Verify transaction details
        XCTAssertTrue(app.staticTexts["Transaction Details"].exists)
        
        // Initiate signing
        app.buttons["Sign & Send"].tap()
        
        // Handle biometric authentication if prompted
        handleBiometricPrompt()
        
        // Wait for signing process
        let signingIndicator = app.activityIndicators["signingTransaction"]
        XCTAssertTrue(signingIndicator.waitForExistence(timeout: 2))
        
        // Wait for success
        let successAlert = app.alerts["Transaction Sent"]
        XCTAssertTrue(successAlert.waitForExistence(timeout: 30))
        
        // Dismiss alert
        successAlert.buttons["OK"].tap()
    }
    
    /// Test error handling when MPC service is unavailable
    func testMPCServiceUnavailable() throws {
        // Launch app with MPC service unavailable
        app.launchEnvironment["MOCK_MPC_ERROR"] = "service_unavailable"
        app.launch()
        
        // Try to create profile
        app.buttons["Create New Profile"].tap()
        
        let profileNameField = app.textFields["profileNameField"]
        profileNameField.tap()
        profileNameField.typeText("Test Profile")
        
        app.buttons["createProfileButton"].tap()
        
        // Verify error alert
        let errorAlert = app.alerts["MPC Service Unavailable"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 10))
        
        // Check error message
        let errorMessage = errorAlert.staticTexts.element(boundBy: 1).label
        XCTAssertTrue(errorMessage.contains("service is temporarily unavailable"))
        
        errorAlert.buttons["OK"].tap()
    }
    
    /// Test wallet backup flow
    func testWalletBackup() throws {
        navigateToProfileWithMPCWallet()
        
        // Navigate to settings
        app.tabBars.buttons["Settings"].tap()
        
        // Find wallet section
        app.tables.cells["Wallet & Security"].tap()
        
        // Tap backup wallet
        app.buttons["Backup Wallet"].tap()
        
        // Handle warning
        let warningAlert = app.alerts["Important"]
        if warningAlert.waitForExistence(timeout: 2) {
            warningAlert.buttons["I Understand"].tap()
        }
        
        // Enter backup password
        let passwordField = app.secureTextFields["backupPassword"]
        passwordField.tap()
        passwordField.typeText("TestPassword123!")
        
        let confirmField = app.secureTextFields["confirmPassword"]
        confirmField.tap()
        confirmField.typeText("TestPassword123!")
        
        // Create backup
        app.buttons["Create Backup"].tap()
        
        // Handle biometric authentication
        handleBiometricPrompt()
        
        // Wait for backup creation
        let backupComplete = app.staticTexts["Backup Created Successfully"]
        XCTAssertTrue(backupComplete.waitForExistence(timeout: 30))
    }
    
    /// Test wallet recovery status
    func testWalletRecoveryStatus() throws {
        navigateToProfileWithMPCWallet()
        
        // Check if wallet shows as MPC
        app.tabBars.buttons["Wallet"].tap()
        
        // Look for MPC indicator
        let mpcBadge = app.staticTexts["MPC"]
        XCTAssertTrue(mpcBadge.exists)
        
        // Verify wallet type in details
        app.buttons["walletInfo"].tap()
        
        let walletType = app.staticTexts["walletType"]
        XCTAssertEqual(walletType.label, "Multi-Party Computation (2-2)")
    }
    
    // MARK: - Helper Methods
    
    private func navigateToProfileWithMPCWallet() {
        // This assumes we have a test profile with MPC wallet
        // In real tests, you might need to create one first
        
        let profileCell = app.tables.cells.containing(.staticText, identifier: "Test MPC Profile").element
        if profileCell.waitForExistence(timeout: 5) {
            profileCell.tap()
        } else {
            // Create profile if it doesn't exist
            try? testCreateProfileWithMPCWallet()
        }
    }
    
    private func handleBiometricPrompt() {
        // In UI tests, we can't actually authenticate with biometrics
        // But we can check that the prompt appears
        
        let biometricPrompt = app.staticTexts["Sign Transaction"]
        if biometricPrompt.waitForExistence(timeout: 2) {
            // In a real device test, the user would authenticate here
            // For testing, we might need to mock the response
            print("Biometric prompt appeared as expected")
        }
    }
}

// MARK: - Accessibility Tests

extension MPCWalletUITests {
    
    /// Test MPC wallet accessibility
    func testMPCWalletAccessibility() throws {
        navigateToProfileWithMPCWallet()
        
        app.tabBars.buttons["Wallet"].tap()
        
        // Check accessibility labels
        let walletAddress = app.staticTexts["walletAddress"]
        XCTAssertNotNil(walletAddress.value(forKey: "accessibilityLabel"))
        
        // Check VoiceOver hints
        let sendButton = app.buttons["Send"]
        XCTAssertNotNil(sendButton.value(forKey: "accessibilityHint"))
        
        // Verify MPC indicator is accessible
        let mpcIndicator = app.staticTexts["MPC"]
        let mpcLabel = mpcIndicator.value(forKey: "accessibilityLabel") as? String
        XCTAssertTrue(mpcLabel?.contains("Multi-Party Computation") ?? false)
    }
}

// MARK: - Performance UI Tests

extension MPCWalletUITests {
    
    /// Measure time to generate MPC wallet
    func testMPCWalletGenerationPerformance() throws {
        measure(metrics: [XCTClockMetric()]) {
            app.launch()
            
            // Create profile with MPC
            app.buttons["Create New Profile"].tap()
            
            let profileNameField = app.textFields["profileNameField"]
            profileNameField.tap()
            profileNameField.typeText("Perf Test \(UUID().uuidString)")
            
            app.buttons["createProfileButton"].tap()
            
            // Wait for wallet generation
            let walletAddress = app.staticTexts["walletAddress"]
            _ = walletAddress.waitForExistence(timeout: 60)
        }
    }
}