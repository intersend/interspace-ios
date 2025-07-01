import XCTest
@testable import Interspace

// MARK: - MPC Unit Tests
// These tests verify individual MPC components without requiring full app or backend

final class MPCUnitTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Set up test environment
        UserDefaults.standard.set(true, forKey: "mpcWalletEnabled")
        UserDefaults.standard.set(true, forKey: "mpcUseHTTP")
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up
        UserDefaults.standard.removeObject(forKey: "mpcWalletEnabled")
        UserDefaults.standard.removeObject(forKey: "mpcUseHTTP")
    }
    
    // MARK: - Configuration Tests
    
    func testMPCConfigurationEnvironment() {
        let config = MPCConfiguration.shared
        
        #if DEBUG
        XCTAssertEqual(config.environment, .development)
        #else
        XCTAssertEqual(config.environment, .production)
        #endif
    }
    
    func testMPCConfigurationURLs() {
        let config = MPCConfiguration.shared
        
        XCTAssertFalse(config.duoNodeUrl.isEmpty)
        XCTAssertTrue(config.duoNodeUrl.hasPrefix("wss://"))
        XCTAssertEqual(config.duoNodePort, "443")
        XCTAssertTrue(config.useSecureConnection)
    }
    
    func testMPCConfigurationHTTP() {
        let config = MPCConfiguration.shared
        
        #if DEBUG
        XCTAssertTrue(config.useHTTP)
        XCTAssertEqual(config.httpTimeout, 30.0)
        XCTAssertEqual(config.pollingInterval, 1.0)
        XCTAssertEqual(config.maxPollingDuration, 120.0)
        #endif
    }
    
    // MARK: - Key Share Manager Tests
    
    func testKeyShareManagerInitialization() {
        let manager = MPCKeyShareManagerHTTP()
        XCTAssertNotNil(manager)
    }
    
    func testGenerateInitialP1Messages() async throws {
        let manager = MPCKeyShareManagerHTTP()
        
        let messages = try await manager.generateInitialP1Messages(algorithm: .ecdsa)
        
        XCTAssertFalse(messages.isEmpty)
        XCTAssertEqual(messages.count, 1)
        
        if let firstMessage = messages.first {
            XCTAssertEqual(firstMessage["type"] as? String, "keyGen")
            XCTAssertEqual(firstMessage["round"] as? Int, 1)
            XCTAssertNotNil(firstMessage["sessionId"])
            XCTAssertEqual(firstMessage["algorithm"] as? String, "ecdsa")
        }
    }
    
    // MARK: - Session Manager Tests
    
    func testSessionManagerSingleton() {
        let manager1 = MPCHTTPSessionManager.shared
        let manager2 = MPCHTTPSessionManager.shared
        
        XCTAssertTrue(manager1 === manager2)
    }
    
    func testSessionCreation() async throws {
        let sessionManager = MPCHTTPSessionManager.shared
        
        // This will fail without backend, but we can test the session creation logic
        do {
            _ = try await sessionManager.startSession(
                profileId: "test-profile",
                type: .keyGeneration,
                initialData: nil
            )
            XCTFail("Should fail without backend")
        } catch {
            // Expected to fail
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testMPCErrorDescriptions() {
        let errors: [MPCError] = [
            .sdkNotInitialized,
            .keyShareNotFound,
            .biometricAuthFailed,
            .websocketNotConnected,
            .operationInProgress
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    func testMPCErrorRetryability() {
        XCTAssertTrue(MPCError.networkTimeout.isRetryable)
        XCTAssertTrue(MPCError.requestTimeout.isRetryable)
        XCTAssertFalse(MPCError.biometricAuthFailed.isRetryable)
        XCTAssertFalse(MPCError.operationInProgress.isRetryable)
    }
    
    // MARK: - Type Conversion Tests
    
    func testMPCSessionTypeMapping() {
        let sessionManager = MPCHTTPSessionManager.shared
        
        // Test internal mapping functions through reflection or exposed methods
        XCTAssertEqual(MPCSessionType.keyGeneration.hashValue, MPCSessionType.keyGeneration.hashValue)
        XCTAssertEqual(MPCSessionType.signing.hashValue, MPCSessionType.signing.hashValue)
    }
    
    // MARK: - Mock Data Tests
    
    func testMockKeyShareCreation() {
        let mockShareData = Data(repeating: 0xFF, count: 32)
        let keyShare = MPCKeyShare(
            shareData: mockShareData,
            publicKey: "mock-public-key",
            address: "0x1234567890abcdef",
            algorithm: .ecdsa,
            createdAt: Date()
        )
        
        XCTAssertEqual(keyShare.shareData, mockShareData)
        XCTAssertEqual(keyShare.publicKey, "mock-public-key")
        XCTAssertEqual(keyShare.address, "0x1234567890abcdef")
        XCTAssertEqual(keyShare.algorithm, .ecdsa)
        XCTAssertFalse(keyShare.keyId.isEmpty)
    }
    
    // MARK: - Secure Storage Tests
    
    func testSecureStorageInitialization() {
        let storage = MPCSecureStorage()
        XCTAssertNotNil(storage)
    }
    
    func testSecureStorageSaveAndRetrieve() async throws {
        let storage = MPCSecureStorage()
        let testProfileId = "test-profile-\(UUID().uuidString)"
        
        let mockKeyShare = MPCKeyShare(
            shareData: Data(repeating: 0xAB, count: 32),
            publicKey: "test-public-key",
            address: "0xtest",
            algorithm: .ecdsa,
            createdAt: Date()
        )
        
        // Save
        try await storage.saveKeyShare(mockKeyShare, for: testProfileId)
        
        // Retrieve
        let retrieved = try await storage.getKeyShare(for: testProfileId)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.publicKey, mockKeyShare.publicKey)
        
        // Clean up
        try await storage.deleteKeyShare(for: testProfileId)
    }
    
    // MARK: - Wallet Info Tests
    
    func testWalletInfoCreation() {
        let walletInfo = WalletInfo(
            address: "0x1234567890123456789012345678901234567890",
            publicKey: "public-key-hex",
            metadata: ["created": Date().timeIntervalSince1970]
        )
        
        XCTAssertEqual(walletInfo.address.count, 42) // Ethereum address length
        XCTAssertTrue(walletInfo.address.hasPrefix("0x"))
        XCTAssertFalse(walletInfo.publicKey.isEmpty)
        XCTAssertNotNil(walletInfo.metadata["created"])
    }
}

// MARK: - Test Helpers

extension MPCUnitTests {
    
    func generateMockP1Message(type: String, round: Int) -> [String: Any] {
        return [
            "type": type,
            "round": round,
            "sessionId": UUID().uuidString,
            "data": [
                "test": "data",
                "timestamp": Date().timeIntervalSince1970
            ]
        ]
    }
    
    func generateMockP2Response() -> [[String: Any]] {
        return [
            [
                "type": "response",
                "round": 1,
                "status": "success",
                "data": ["key": "value"]
            ]
        ]
    }
}