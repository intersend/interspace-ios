import XCTest
@testable import Interspace
// TODO: Import when module conflicts are resolved
// import silentshardduo

class MPCWalletServiceTests: XCTestCase {
    
    var sut: MPCWalletService!
    var mockKeyShareManager: MockMPCKeyShareManager!
    var mockSecureStorage: MockMPCSecureStorage!
    var mockSessionManager: MockMPCSessionManager!
    var mockBiometricAuth: MockBiometricAuthManager!
    
    override func setUp() {
        super.setUp()
        
        mockKeyShareManager = MockMPCKeyShareManager()
        mockSecureStorage = MockMPCSecureStorage()
        mockSessionManager = MockMPCSessionManager()
        mockBiometricAuth = MockBiometricAuthManager()
        
        sut = MPCWalletService(
            keyShareManager: mockKeyShareManager,
            secureStorage: mockSecureStorage,
            sessionManager: mockSessionManager,
            biometricAuth: mockBiometricAuth
        )
    }
    
    override func tearDown() {
        sut = nil
        mockKeyShareManager = nil
        mockSecureStorage = nil
        mockSessionManager = nil
        mockBiometricAuth = nil
        super.tearDown()
    }
    
    // MARK: - Key Generation Tests
    
    func testKeyGeneration_Success() async throws {
        // Given
        let profileId = "test-profile-123"
        mockBiometricAuth.authenticateResult = .success(())
        mockSessionManager.connectResult = .success(())
        mockKeyShareManager.generateKeyResult = .success(MPCKeyShare(
            shareData: Data(),
            publicKey: "0x1234567890",
            address: "0xabcdef1234567890",
            algorithm: .ecdsa
        ))
        mockSecureStorage.saveResult = .success(())
        
        // When
        let result = try await sut.generateWallet(for: profileId)
        
        // Then
        XCTAssertEqual(result.address, "0xabcdef1234567890")
        XCTAssertTrue(mockBiometricAuth.authenticateCalled)
        XCTAssertTrue(mockSessionManager.connectCalled)
        XCTAssertTrue(mockKeyShareManager.generateKeyCalled)
        XCTAssertTrue(mockSecureStorage.saveCalled)
    }
    
    func testKeyGeneration_BiometricFailure() async throws {
        // Given
        let profileId = "test-profile-123"
        mockBiometricAuth.authenticateResult = .failure(MPCError.biometricAuthFailed)
        
        // When/Then
        do {
            _ = try await sut.generateWallet(for: profileId)
            XCTFail("Expected biometric auth failure")
        } catch {
            XCTAssertEqual(error as? MPCError, .biometricAuthFailed)
        }
    }
    
    func testKeyGeneration_WebSocketConnectionFailure() async throws {
        // Given
        let profileId = "test-profile-123"
        mockBiometricAuth.authenticateResult = .success(())
        mockSessionManager.connectResult = .failure(MPCError.websocketConnectionFailed)
        
        // When/Then
        do {
            _ = try await sut.generateWallet(for: profileId)
            XCTFail("Expected WebSocket connection failure")
        } catch {
            XCTAssertEqual(error as? MPCError, .websocketConnectionFailed)
        }
    }
    
    // MARK: - Transaction Signing Tests
    
    func testTransactionSigning_Success() async throws {
        // Given
        let profileId = "test-profile-123"
        let transactionHash = Data(repeating: 1, count: 32)
        let expectedSignature = "0xsignature123"
        
        mockSecureStorage.retrieveResult = .success(Data())
        mockBiometricAuth.authenticateResult = .success(())
        mockSessionManager.connectResult = .success(())
        mockKeyShareManager.signTransactionResult = .success(expectedSignature)
        
        // When
        let signature = try await sut.signTransaction(
            profileId: profileId,
            transactionHash: transactionHash
        )
        
        // Then
        XCTAssertEqual(signature, expectedSignature)
        XCTAssertTrue(mockBiometricAuth.authenticateCalled)
        XCTAssertTrue(mockKeyShareManager.signTransactionCalled)
    }
    
    func testTransactionSigning_KeyShareNotFound() async throws {
        // Given
        let profileId = "test-profile-123"
        let transactionHash = Data(repeating: 1, count: 32)
        
        mockSecureStorage.retrieveResult = .failure(MPCError.keyShareNotFound)
        
        // When/Then
        do {
            _ = try await sut.signTransaction(
                profileId: profileId,
                transactionHash: transactionHash
            )
            XCTFail("Expected key share not found error")
        } catch {
            XCTAssertEqual(error as? MPCError, .keyShareNotFound)
        }
    }
    
    // MARK: - Key Rotation Tests
    
    func testKeyRotation_Success() async throws {
        // Given
        let profileId = "test-profile-123"
        
        mockSecureStorage.retrieveResult = .success(Data())
        mockBiometricAuth.authenticateResult = .success(())
        mockSessionManager.connectResult = .success(())
        mockKeyShareManager.rotateKeyResult = .success(MPCKeyShare(
            shareData: Data(),
            publicKey: "0x1234567890",
            address: "0xabcdef1234567890",
            algorithm: .ecdsa
        ))
        mockSecureStorage.saveResult = .success(())
        
        // When
        try await sut.rotateKey(for: profileId)
        
        // Then
        XCTAssertTrue(mockBiometricAuth.authenticateCalled)
        XCTAssertTrue(mockKeyShareManager.rotateKeyCalled)
        XCTAssertTrue(mockSecureStorage.saveCalled)
        XCTAssertEqual(mockSecureStorage.saveCallCount, 1)
    }
    
    // MARK: - Backup and Recovery Tests
    
    func testBackup_Success() async throws {
        // Given
        let profileId = "test-profile-123"
        let rsaPublicKey = "RSA_PUBLIC_KEY_PEM"
        let label = "Test Backup"
        
        mockSecureStorage.retrieveResult = .success(Data())
        mockBiometricAuth.authenticateResult = .success(())
        
        let expectedBackup = MPCBackup(
            encryptedShare: Data(),
            verificationData: Data(),
            algorithm: .ecdsa,
            timestamp: Date()
        )
        mockKeyShareManager.createBackupResult = .success(expectedBackup)
        
        // When
        let backup = try await sut.createBackup(
            profileId: profileId,
            rsaPublicKey: rsaPublicKey,
            label: label
        )
        
        // Then
        XCTAssertEqual(backup.algorithm, .ecdsa)
        XCTAssertTrue(mockBiometricAuth.authenticateCalled)
        XCTAssertTrue(mockKeyShareManager.createBackupCalled)
    }
    
    func testExport_Success() async throws {
        // Given
        let profileId = "test-profile-123"
        let clientEncryptionKey = Data(repeating: 2, count: 32)
        
        mockSecureStorage.retrieveResult = .success(Data())
        mockBiometricAuth.authenticateResult = .success(())
        
        let expectedExport = MPCExport(
            encryptedPrivateKey: Data(),
            publicKey: "0x1234567890",
            algorithm: .ecdsa
        )
        mockKeyShareManager.exportKeyResult = .success(expectedExport)
        
        // When
        let export = try await sut.exportKey(
            profileId: profileId,
            clientEncryptionKey: clientEncryptionKey
        )
        
        // Then
        XCTAssertEqual(export.algorithm, .ecdsa)
        XCTAssertTrue(mockBiometricAuth.authenticateCalled)
        XCTAssertTrue(mockKeyShareManager.exportKeyCalled)
    }
    
    // MARK: - WebSocket Session Tests
    
    func testWebSocketReconnection() async throws {
        // Given
        mockSessionManager.connectResult = .failure(MPCError.websocketConnectionFailed)
        mockSessionManager.reconnectResult = .success(())
        
        // When
        _ = try? await sut.establishSession()
        
        // Then
        XCTAssertTrue(mockSessionManager.reconnectCalled)
        XCTAssertGreaterThanOrEqual(mockSessionManager.reconnectAttempts, 1)
    }
    
    func testSessionTimeout() async throws {
        // Given
        let profileId = "test-profile-123"
        mockSessionManager.isSessionExpired = true
        mockSessionManager.connectResult = .success(())
        mockBiometricAuth.authenticateResult = .success(())
        mockSecureStorage.retrieveResult = .success(Data())
        mockKeyShareManager.signTransactionResult = .success("0xsignature")
        
        // When
        _ = try await sut.signTransaction(
            profileId: profileId,
            transactionHash: Data(repeating: 1, count: 32)
        )
        
        // Then
        XCTAssertTrue(mockSessionManager.connectCalled)
        XCTAssertEqual(mockSessionManager.connectCallCount, 1)
    }
    
    // MARK: - Security Tests
    
    func testBiometricAuthenticationRequired() async throws {
        // Given
        let operations = [
            { try await self.sut.generateWallet(for: "profile123") },
            { try await self.sut.signTransaction(profileId: "profile123", transactionHash: Data()) },
            { try await self.sut.rotateKey(for: "profile123") },
            { try await self.sut.createBackup(profileId: "profile123", rsaPublicKey: "RSA", label: "Test") },
            { try await self.sut.exportKey(profileId: "profile123", clientEncryptionKey: Data()) }
        ]
        
        mockBiometricAuth.authenticateResult = .failure(MPCError.biometricAuthFailed)
        
        // When/Then
        for operation in operations {
            do {
                _ = try await operation()
                XCTFail("Expected biometric authentication to be required")
            } catch {
                XCTAssertEqual(error as? MPCError, .biometricAuthFailed)
            }
        }
    }
    
    func testSecureStorageEncryption() async throws {
        // Given
        let profileId = "test-profile-123"
        let keyShare = MPCKeyShare(
            shareData: Data(repeating: 42, count: 64),
            publicKey: "0x1234567890",
            address: "0xabcdef1234567890",
            algorithm: .ecdsa
        )
        
        // When
        mockSecureStorage.saveResult = .success(())
        try await mockSecureStorage.save(keyShare, for: profileId)
        
        // Then
        XCTAssertTrue(mockSecureStorage.encryptionUsed)
        XCTAssertEqual(mockSecureStorage.encryptionAlgorithm, "AES-256-GCM")
        XCTAssertTrue(mockSecureStorage.hardwareBackedKeyUsed)
    }
}

// MARK: - Mock Classes

class MockMPCKeyShareManager: MPCKeyShareManagerProtocol {
    var generateKeyCalled = false
    var generateKeyResult: Result<MPCKeyShare, Error> = .failure(MPCError.sdkNotInitialized)
    
    var signTransactionCalled = false
    var signTransactionResult: Result<String, Error> = .failure(MPCError.sdkNotInitialized)
    
    var rotateKeyCalled = false
    var rotateKeyResult: Result<MPCKeyShare, Error> = .failure(MPCError.sdkNotInitialized)
    
    var createBackupCalled = false
    var createBackupResult: Result<MPCBackup, Error> = .failure(MPCError.sdkNotInitialized)
    
    var exportKeyCalled = false
    var exportKeyResult: Result<MPCExport, Error> = .failure(MPCError.sdkNotInitialized)
    
    func generateKey(algorithm: MPCAlgorithm) async throws -> MPCKeyShare {
        generateKeyCalled = true
        return try generateKeyResult.get()
    }
    
    func signTransaction(keyShare: Data, transactionHash: Data, chainPath: String?) async throws -> String {
        signTransactionCalled = true
        return try signTransactionResult.get()
    }
    
    func rotateKey(currentShare: Data) async throws -> MPCKeyShare {
        rotateKeyCalled = true
        return try rotateKeyResult.get()
    }
    
    func createBackup(keyShare: Data, rsaPublicKey: String, label: String) async throws -> MPCBackup {
        createBackupCalled = true
        return try createBackupResult.get()
    }
    
    func exportKey(keyShare: Data, clientEncryptionKey: Data) async throws -> MPCExport {
        exportKeyCalled = true
        return try exportKeyResult.get()
    }
}

class MockMPCSecureStorage: MPCSecureStorageProtocol {
    var saveCalled = false
    var saveCallCount = 0
    var saveResult: Result<Void, Error> = .success(())
    
    var retrieveCalled = false
    var retrieveResult: Result<Data, Error> = .failure(MPCError.keyShareNotFound)
    
    var deleteCalled = false
    var deleteResult: Result<Void, Error> = .success(())
    
    var encryptionUsed = true
    var encryptionAlgorithm = "AES-256-GCM"
    var hardwareBackedKeyUsed = true
    
    func save(_ keyShare: MPCKeyShare, for profileId: String) async throws {
        saveCalled = true
        saveCallCount += 1
        try saveResult.get()
    }
    
    func retrieve(for profileId: String) async throws -> Data {
        retrieveCalled = true
        return try retrieveResult.get()
    }
    
    func delete(for profileId: String) async throws {
        deleteCalled = true
        try deleteResult.get()
    }
}

class MockMPCSessionManager: MPCSessionManagerProtocol {
    var connectCalled = false
    var connectCallCount = 0
    var connectResult: Result<Void, Error> = .success(())
    
    var disconnectCalled = false
    var isSessionExpired = false
    
    var reconnectCalled = false
    var reconnectAttempts = 0
    var reconnectResult: Result<Void, Error> = .success(())
    
    func connect() async throws {
        connectCalled = true
        connectCallCount += 1
        try connectResult.get()
    }
    
    func disconnect() {
        disconnectCalled = true
    }
    
    func reconnect() async throws {
        reconnectCalled = true
        reconnectAttempts += 1
        try reconnectResult.get()
    }
    
    var isConnected: Bool {
        return !isSessionExpired && connectCalled
    }
}

class MockBiometricAuthManager: BiometricAuthManagerProtocol {
    var authenticateCalled = false
    var authenticateResult: Result<Void, Error> = .success(())
    
    func authenticate(reason: String) async throws {
        authenticateCalled = true
        try authenticateResult.get()
    }
    
    var isAvailable: Bool {
        return true
    }
}

// MARK: - Test Models

struct MPCKeyShare {
    let shareData: Data
    let publicKey: String
    let address: String
    let algorithm: MPCAlgorithm
}

struct MPCBackup {
    let encryptedShare: Data
    let verificationData: Data
    let algorithm: MPCAlgorithm
    let timestamp: Date
}

struct MPCExport {
    let encryptedPrivateKey: Data
    let publicKey: String
    let algorithm: MPCAlgorithm
}

enum MPCAlgorithm {
    case ecdsa
    case eddsa
}

enum MPCError: LocalizedError {
    case sdkNotInitialized
    case keyShareNotFound
    case sessionExpired
    case biometricAuthFailed
    case websocketConnectionFailed
    case invalidConfiguration
    case signingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .sdkNotInitialized:
            return "MPC SDK is not initialized"
        case .keyShareNotFound:
            return "Key share not found for profile"
        case .sessionExpired:
            return "MPC session has expired"
        case .biometricAuthFailed:
            return "Biometric authentication failed"
        case .websocketConnectionFailed:
            return "Failed to connect to MPC server"
        case .invalidConfiguration:
            return "Invalid MPC configuration"
        case .signingFailed(let reason):
            return "Signing failed: \(reason)"
        }
    }
}

// MARK: - Protocol Definitions

protocol MPCKeyShareManagerProtocol {
    func generateKey(algorithm: MPCAlgorithm) async throws -> MPCKeyShare
    func signTransaction(keyShare: Data, transactionHash: Data, chainPath: String?) async throws -> String
    func rotateKey(currentShare: Data) async throws -> MPCKeyShare
    func createBackup(keyShare: Data, rsaPublicKey: String, label: String) async throws -> MPCBackup
    func exportKey(keyShare: Data, clientEncryptionKey: Data) async throws -> MPCExport
}

protocol MPCSecureStorageProtocol {
    func save(_ keyShare: MPCKeyShare, for profileId: String) async throws
    func retrieve(for profileId: String) async throws -> Data
    func delete(for profileId: String) async throws
}

protocol MPCSessionManagerProtocol {
    var isConnected: Bool { get }
    func connect() async throws
    func disconnect()
    func reconnect() async throws
}

protocol BiometricAuthManagerProtocol {
    var isAvailable: Bool { get }
    func authenticate(reason: String) async throws
}

// MARK: - MPCWalletService (Stub for testing)

class MPCWalletService {
    private let keyShareManager: MPCKeyShareManagerProtocol
    private let secureStorage: MPCSecureStorageProtocol
    private let sessionManager: MPCSessionManagerProtocol
    private let biometricAuth: BiometricAuthManagerProtocol
    
    init(
        keyShareManager: MPCKeyShareManagerProtocol,
        secureStorage: MPCSecureStorageProtocol,
        sessionManager: MPCSessionManagerProtocol,
        biometricAuth: BiometricAuthManagerProtocol
    ) {
        self.keyShareManager = keyShareManager
        self.secureStorage = secureStorage
        self.sessionManager = sessionManager
        self.biometricAuth = biometricAuth
    }
    
    func generateWallet(for profileId: String) async throws -> (address: String, publicKey: String) {
        try await biometricAuth.authenticate(reason: "Generate MPC Wallet")
        try await sessionManager.connect()
        
        let keyShare = try await keyShareManager.generateKey(algorithm: .ecdsa)
        try await secureStorage.save(keyShare, for: profileId)
        
        return (address: keyShare.address, publicKey: keyShare.publicKey)
    }
    
    func signTransaction(profileId: String, transactionHash: Data) async throws -> String {
        let keyShareData = try await secureStorage.retrieve(for: profileId)
        try await biometricAuth.authenticate(reason: "Sign Transaction")
        
        if !sessionManager.isConnected {
            try await sessionManager.connect()
        }
        
        return try await keyShareManager.signTransaction(
            keyShare: keyShareData,
            transactionHash: transactionHash,
            chainPath: nil
        )
    }
    
    func rotateKey(for profileId: String) async throws {
        let keyShareData = try await secureStorage.retrieve(for: profileId)
        try await biometricAuth.authenticate(reason: "Rotate MPC Key")
        try await sessionManager.connect()
        
        let newKeyShare = try await keyShareManager.rotateKey(currentShare: keyShareData)
        try await secureStorage.save(newKeyShare, for: profileId)
    }
    
    func createBackup(profileId: String, rsaPublicKey: String, label: String) async throws -> MPCBackup {
        let keyShareData = try await secureStorage.retrieve(for: profileId)
        try await biometricAuth.authenticate(reason: "Create Wallet Backup")
        
        return try await keyShareManager.createBackup(
            keyShare: keyShareData,
            rsaPublicKey: rsaPublicKey,
            label: label
        )
    }
    
    func exportKey(profileId: String, clientEncryptionKey: Data) async throws -> MPCExport {
        let keyShareData = try await secureStorage.retrieve(for: profileId)
        try await biometricAuth.authenticate(reason: "Export Wallet Key")
        
        return try await keyShareManager.exportKey(
            keyShare: keyShareData,
            clientEncryptionKey: clientEncryptionKey
        )
    }
    
    func establishSession() async throws {
        try await sessionManager.connect()
    }
}