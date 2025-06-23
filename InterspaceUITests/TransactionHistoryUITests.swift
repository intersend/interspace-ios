import XCTest

class TransactionHistoryUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        UITestMockDataProvider.configure(app: app, for: .walletUser)
        app.launchEnvironment["MOCK_TRANSACTIONS"] = "true"
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Transaction History View Tests
    
    func testTransactionHistoryAccess() {
        // Navigate to wallet tab
        UITestHelpers.navigateToTab(.wallet, in: app)
        
        // Verify transaction history button exists
        let transactionHistoryButton = app.buttons[AccessibilityIdentifiers.Wallet.transactionHistory]
        XCTAssertTrue(transactionHistoryButton.waitForExistence(timeout: 2))
        
        // Tap to view transaction history
        transactionHistoryButton.tap()
        
        // Verify transaction history view appears
        let historyView = app.otherElements["TransactionHistoryView"]
        XCTAssertTrue(historyView.waitForExistence(timeout: 2))
        
        // Verify navigation title
        XCTAssertTrue(app.navigationBars["Transaction History"].exists)
        
        screenshots.captureScreen(named: "TransactionHistory_View")
    }
    
    func testTransactionListDisplay() {
        // Navigate to transaction history
        UITestHelpers.navigateToTab(.wallet, in: app)
        app.buttons[AccessibilityIdentifiers.Wallet.transactionHistory].tap()
        
        // Verify transaction list
        let transactionList = app.tables[AccessibilityIdentifiers.Transaction.historyList]
        XCTAssertTrue(transactionList.waitForExistence(timeout: 2))
        
        // Verify mock transactions are displayed
        let transaction1 = transactionList.cells.element(boundBy: 0)
        let transaction2 = transactionList.cells.element(boundBy: 1)
        let transaction3 = transactionList.cells.element(boundBy: 2)
        
        XCTAssertTrue(transaction1.exists)
        XCTAssertTrue(transaction2.exists)
        XCTAssertTrue(transaction3.exists)
        
        // Verify transaction details
        XCTAssertTrue(transaction1.staticTexts["0.5 ETH"].exists)
        XCTAssertTrue(transaction1.staticTexts["Confirmed"].exists)
        
        XCTAssertTrue(transaction2.staticTexts["100 USDC"].exists)
        XCTAssertTrue(transaction2.staticTexts["Pending"].exists)
        
        XCTAssertTrue(transaction3.staticTexts["1 NFT"].exists)
        XCTAssertTrue(transaction3.staticTexts["Failed"].exists)
        
        screenshots.captureScreen(named: "TransactionList")
    }
    
    func testTransactionStatusIndicators() {
        // Navigate to transaction history
        UITestHelpers.navigateToTab(.wallet, in: app)
        app.buttons[AccessibilityIdentifiers.Wallet.transactionHistory].tap()
        
        let transactionList = app.tables[AccessibilityIdentifiers.Transaction.historyList]
        
        // Verify status indicators
        let confirmedIndicator = transactionList.cells.element(boundBy: 0).images["status_confirmed"]
        let pendingIndicator = transactionList.cells.element(boundBy: 1).images["status_pending"]
        let failedIndicator = transactionList.cells.element(boundBy: 2).images["status_failed"]
        
        XCTAssertTrue(confirmedIndicator.exists)
        XCTAssertTrue(pendingIndicator.exists)
        XCTAssertTrue(failedIndicator.exists)
        
        // Verify status colors (through accessibility)
        XCTAssertEqual(confirmedIndicator.label, "Confirmed transaction")
        XCTAssertEqual(pendingIndicator.label, "Pending transaction")
        XCTAssertEqual(failedIndicator.label, "Failed transaction")
    }
    
    func testTransactionDetailView() {
        // Navigate to transaction history
        UITestHelpers.navigateToTab(.wallet, in: app)
        app.buttons[AccessibilityIdentifiers.Wallet.transactionHistory].tap()
        
        // Tap on a transaction
        let transactionList = app.tables[AccessibilityIdentifiers.Transaction.historyList]
        let firstTransaction = transactionList.cells.element(boundBy: 0)
        firstTransaction.tap()
        
        // Verify detail view appears
        let detailView = app.otherElements[AccessibilityIdentifiers.Transaction.transactionDetail]
        XCTAssertTrue(detailView.waitForExistence(timeout: 2))
        
        // Verify transaction details
        XCTAssertTrue(app.staticTexts["Transaction Details"].exists)
        XCTAssertTrue(app.staticTexts["Hash:"].exists)
        XCTAssertTrue(app.staticTexts["0x123...abc"].exists)
        XCTAssertTrue(app.staticTexts["From:"].exists)
        XCTAssertTrue(app.staticTexts["0x742d35Cc6634C0532925a3b844Bc9e7595f6BEd4"].exists)
        XCTAssertTrue(app.staticTexts["To:"].exists)
        XCTAssertTrue(app.staticTexts["0x456...def"].exists)
        XCTAssertTrue(app.staticTexts["Amount:"].exists)
        XCTAssertTrue(app.staticTexts["0.5 ETH"].exists)
        XCTAssertTrue(app.staticTexts["Status:"].exists)
        XCTAssertTrue(app.staticTexts["Confirmed"].exists)
        
        // Verify action buttons
        XCTAssertTrue(app.buttons["View on Etherscan"].exists)
        XCTAssertTrue(app.buttons["Copy Transaction Hash"].exists)
        
        screenshots.captureScreen(named: "TransactionDetail")
    }
    
    func testTransactionFiltering() {
        // Navigate to transaction history
        UITestHelpers.navigateToTab(.wallet, in: app)
        app.buttons[AccessibilityIdentifiers.Wallet.transactionHistory].tap()
        
        // Verify filter options
        let filterButton = app.buttons["Filter"]
        XCTAssertTrue(filterButton.exists)
        filterButton.tap()
        
        // Verify filter options sheet
        let filterSheet = app.sheets["Filter Transactions"]
        XCTAssertTrue(filterSheet.waitForExistence(timeout: 2))
        
        // Verify filter options
        XCTAssertTrue(filterSheet.buttons["All"].exists)
        XCTAssertTrue(filterSheet.buttons["Sent"].exists)
        XCTAssertTrue(filterSheet.buttons["Received"].exists)
        XCTAssertTrue(filterSheet.buttons["Pending"].exists)
        XCTAssertTrue(filterSheet.buttons["Failed"].exists)
        
        // Apply filter for pending transactions
        filterSheet.buttons["Pending"].tap()
        
        // Verify only pending transactions shown
        let transactionList = app.tables[AccessibilityIdentifiers.Transaction.historyList]
        XCTAssertEqual(transactionList.cells.count, 1)
        XCTAssertTrue(transactionList.cells.firstMatch.staticTexts["Pending"].exists)
        
        screenshots.captureScreen(named: "FilteredTransactions_Pending")
    }
    
    func testTransactionSearch() {
        // Navigate to transaction history
        UITestHelpers.navigateToTab(.wallet, in: app)
        app.buttons[AccessibilityIdentifiers.Wallet.transactionHistory].tap()
        
        // Tap search button
        let searchButton = app.buttons["Search"]
        XCTAssertTrue(searchButton.exists)
        searchButton.tap()
        
        // Verify search bar appears
        let searchBar = app.searchFields[AccessibilityIdentifiers.Common.searchBar]
        XCTAssertTrue(searchBar.waitForExistence(timeout: 2))
        
        // Search by transaction hash
        searchBar.tap()
        searchBar.typeText("0x123")
        
        // Verify filtered results
        let transactionList = app.tables[AccessibilityIdentifiers.Transaction.historyList]
        XCTAssertEqual(transactionList.cells.count, 1)
        XCTAssertTrue(transactionList.cells.firstMatch.staticTexts["0x123...abc"].exists)
        
        screenshots.captureScreen(named: "TransactionSearch")
    }
    
    // MARK: - Send Transaction Tests
    
    func testSendTokenFlow() {
        // Navigate to wallet tab
        UITestHelpers.navigateToTab(.wallet, in: app)
        
        // Tap send button
        let sendButton = app.buttons[AccessibilityIdentifiers.Transaction.sendButton]
        XCTAssertTrue(sendButton.exists)
        sendButton.tap()
        
        // Verify send token sheet appears
        let sendSheet = app.sheets["Send Token"]
        XCTAssertTrue(sendSheet.waitForExistence(timeout: 2))
        
        // Select token type
        let tokenSelector = sendSheet.buttons["Select Token"]
        tokenSelector.tap()
        
        let ethOption = app.buttons["ETH"]
        XCTAssertTrue(ethOption.waitForExistence(timeout: 1))
        ethOption.tap()
        
        // Enter recipient address
        let recipientField = sendSheet.textFields[AccessibilityIdentifiers.Transaction.recipientField]
        recipientField.tap()
        recipientField.typeText("0x123d35Cc6634C0532925a3b844Bc9e7595f6BEd5")
        
        // Enter amount
        let amountField = sendSheet.textFields[AccessibilityIdentifiers.Transaction.amountField]
        amountField.tap()
        amountField.typeText("0.1")
        
        // Verify gas options
        let gasSelector = sendSheet.buttons[AccessibilityIdentifiers.Transaction.gasSelector]
        XCTAssertTrue(gasSelector.exists)
        gasSelector.tap()
        
        // Select standard gas
        app.buttons["Standard"].tap()
        
        screenshots.captureScreen(named: "SendToken_Form")
        
        // Review transaction
        sendSheet.buttons["Review"].tap()
        
        // Verify confirmation screen
        XCTAssertTrue(app.staticTexts["Review Transaction"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["To: 0x123d...BEd5"].exists)
        XCTAssertTrue(app.staticTexts["Amount: 0.1 ETH"].exists)
        XCTAssertTrue(app.staticTexts["Network Fee: ~0.002 ETH"].exists)
        
        // Confirm transaction
        let confirmButton = app.buttons[AccessibilityIdentifiers.Transaction.confirmButton]
        confirmButton.tap()
        
        // Mock wallet signature
        let signatureAlert = app.alerts["Confirm Transaction"]
        if signatureAlert.waitForExistence(timeout: 2) {
            signatureAlert.buttons["Confirm"].tap()
        }
        
        // Verify transaction submitted
        XCTAssertTrue(app.staticTexts["Transaction Submitted"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Your transaction has been submitted to the network"].exists)
        
        screenshots.captureScreen(named: "TransactionSubmitted")
    }
    
    func testReceiveTokenFlow() {
        // Navigate to wallet tab
        UITestHelpers.navigateToTab(.wallet, in: app)
        
        // Tap receive button
        let receiveButton = app.buttons[AccessibilityIdentifiers.Transaction.receiveButton]
        XCTAssertTrue(receiveButton.exists)
        receiveButton.tap()
        
        // Verify receive sheet appears
        let receiveSheet = app.sheets["Receive Tokens"]
        XCTAssertTrue(receiveSheet.waitForExistence(timeout: 2))
        
        // Verify wallet address is displayed
        XCTAssertTrue(receiveSheet.staticTexts["0x742d35Cc6634C0532925a3b844Bc9e7595f6BEd4"].exists)
        
        // Verify QR code
        XCTAssertTrue(receiveSheet.images["AddressQRCode"].exists)
        
        // Verify copy button
        let copyButton = receiveSheet.buttons["Copy Address"]
        XCTAssertTrue(copyButton.exists)
        
        // Test copy functionality
        copyButton.tap()
        XCTAssertTrue(app.staticTexts["Address Copied!"].waitForExistence(timeout: 1))
        
        // Verify share button
        let shareButton = receiveSheet.buttons["Share"]
        XCTAssertTrue(shareButton.exists)
        
        screenshots.captureScreen(named: "ReceiveTokens")
    }
    
    // MARK: - Transaction Refresh and Loading Tests
    
    func testTransactionListRefresh() {
        // Navigate to transaction history
        UITestHelpers.navigateToTab(.wallet, in: app)
        app.buttons[AccessibilityIdentifiers.Wallet.transactionHistory].tap()
        
        let transactionList = app.tables[AccessibilityIdentifiers.Transaction.historyList]
        
        // Pull to refresh
        UITestHelpers.pullToRefresh(in: transactionList)
        
        // Verify refresh indicator
        let refreshControl = app.otherElements[AccessibilityIdentifiers.Common.refreshControl]
        XCTAssertTrue(refreshControl.waitForExistence(timeout: 1))
        
        // Wait for refresh to complete
        Thread.sleep(forTimeInterval: 1.5)
        
        // Verify list is updated (in mock, we add a new transaction)
        XCTAssertTrue(transactionList.cells.element(boundBy: 0).staticTexts["New Transaction"].waitForExistence(timeout: 2))
        
        screenshots.captureScreen(named: "TransactionList_Refreshed")
    }
    
    func testEmptyTransactionHistory() {
        // Configure for empty state
        app.terminate()
        app.launchEnvironment["EMPTY_TRANSACTIONS"] = "true"
        app.launch()
        
        // Navigate to transaction history
        UITestHelpers.navigateToTab(.wallet, in: app)
        app.buttons[AccessibilityIdentifiers.Wallet.transactionHistory].tap()
        
        // Verify empty state
        let emptyStateView = app.otherElements[AccessibilityIdentifiers.Common.emptyStateView]
        XCTAssertTrue(emptyStateView.waitForExistence(timeout: 2))
        
        XCTAssertTrue(app.staticTexts["No Transactions Yet"].exists)
        XCTAssertTrue(app.staticTexts["Your transaction history will appear here"].exists)
        XCTAssertTrue(app.images["empty_transactions_illustration"].exists)
        
        // Verify send button in empty state
        XCTAssertTrue(app.buttons["Make Your First Transaction"].exists)
        
        screenshots.captureScreen(named: "TransactionHistory_Empty")
    }
    
    func testTransactionNotifications() {
        // Navigate to wallet tab
        UITestHelpers.navigateToTab(.wallet, in: app)
        
        // Initiate a transaction
        app.buttons[AccessibilityIdentifiers.Transaction.sendButton].tap()
        
        // Quick send (using recent address)
        let recentAddressCell = app.cells["recent_0x123d...BEd5"]
        if recentAddressCell.waitForExistence(timeout: 1) {
            recentAddressCell.tap()
        }
        
        // Enter amount and send
        let amountField = app.textFields[AccessibilityIdentifiers.Transaction.amountField]
        amountField.tap()
        amountField.typeText("0.05")
        
        app.buttons["Send"].tap()
        app.buttons["Confirm"].tap()
        
        // Verify in-app notification
        let notification = app.otherElements["TransactionNotification"]
        XCTAssertTrue(notification.waitForExistence(timeout: 3))
        XCTAssertTrue(notification.staticTexts["Transaction Pending"].exists)
        
        // Wait for confirmation (mocked)
        Thread.sleep(forTimeInterval: 2)
        
        // Verify confirmation notification
        XCTAssertTrue(notification.staticTexts["Transaction Confirmed"].waitForExistence(timeout: 2))
        
        screenshots.captureScreen(named: "TransactionNotification")
    }
    
    // MARK: - Transaction Export Tests
    
    func testExportTransactionHistory() {
        // Navigate to transaction history
        UITestHelpers.navigateToTab(.wallet, in: app)
        app.buttons[AccessibilityIdentifiers.Wallet.transactionHistory].tap()
        
        // Tap more options
        let moreButton = app.buttons["More"]
        XCTAssertTrue(moreButton.exists)
        moreButton.tap()
        
        // Verify export options
        let actionSheet = app.sheets["Transaction Options"]
        XCTAssertTrue(actionSheet.waitForExistence(timeout: 2))
        
        XCTAssertTrue(actionSheet.buttons["Export as CSV"].exists)
        XCTAssertTrue(actionSheet.buttons["Export as PDF"].exists)
        
        // Select CSV export
        actionSheet.buttons["Export as CSV"].tap()
        
        // Verify share sheet appears
        let shareSheet = app.otherElements["ActivityViewController"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 2))
        
        screenshots.captureScreen(named: "TransactionExport")
    }
}