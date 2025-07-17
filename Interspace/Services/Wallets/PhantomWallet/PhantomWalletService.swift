import Foundation
import Combine
import UIKit

/// Phantom wallet implementation
/// Handles connection, signing, and transaction operations via deep links
///
/// IMPORTANT: Phantom deep links are designed for Solana and return Solana addresses.
/// For Ethereum/EVM authentication:
/// - Deep links will return Solana public keys, not Ethereum addresses
/// - SIWE (Sign-In With Ethereum) will fail with address format mismatch
/// - Recommended: Use WalletConnect or other wallets for Ethereum
///
/// This implementation is kept for future Solana support or if Phantom
/// adds proper Ethereum deep link support.
final class PhantomWalletService: WalletProtocol {
    
    // MARK: - Properties
    
    let walletType: WalletType = .phantom
    let connectionState = CurrentValueSubject<WalletConnectionState, Never>(.disconnected)
    private(set) var currentSession: WalletSession?
    
    // Encryption
    private var encryptionKeyPair: PhantomEncryption.KeyPair?
    private var phantomPublicKey: Data?
    
    // Pending operations
    private var pendingConnectCompletion: ((Result<WalletSession, WalletError>) -> Void)?
    private var pendingSignMessageCompletion: ((Result<WalletSignature, WalletError>) -> Void)?
    private var pendingSignTransactionCompletion: ((Result<String, WalletError>) -> Void)?
    private var pendingSendTransactionCompletion: ((Result<String, WalletError>) -> Void)?
    
    // Timeout handling
    private var timeoutTimer: Timer?
    private let requestTimeout: TimeInterval = 60.0
    
    // Session storage
    private let sessionStorage: WalletSessionStorageProtocol
    
    // MARK: - Initialization
    
    init(sessionStorage: WalletSessionStorageProtocol = WalletSessionStorage.shared) {
        self.sessionStorage = sessionStorage
        
        // Try to restore session
        Task {
            await restoreSession()
        }
    }
    
    // MARK: - WalletProtocol Implementation
    
    func supportsChain(_ chainId: Int) -> Bool {
        // NOTE: Phantom deep links primarily support Solana
        // For Ethereum support, WalletConnect is recommended
        // Deep links will return Solana addresses, not Ethereum addresses
        return false // Disabled for now since deep links don't support Ethereum properly
    }
    
    func connect(
        context: WalletConnectionContext,
        completion: @escaping (Result<WalletSession, WalletError>) -> Void
    ) {
        // Check if Phantom is installed
        guard isPhantomInstalled() else {
            completion(.failure(.walletNotInstalled))
            return
        }
        
        // Cancel any pending connection
        cancelPendingOperations()
        
        // Update state
        connectionState.send(.connecting)
        
        // Generate encryption keypair
        encryptionKeyPair = PhantomEncryption.generateKeyPair()
        guard let keyPair = encryptionKeyPair else {
            completion(.failure(.connectionFailed("Failed to generate encryption keys")))
            return
        }
        
        // Build connect URL
        guard let url = PhantomDeepLinks.buildConnectURL(
            appUrl: context.appUrl,
            publicKey: Base58.encode(keyPair.publicKey),
            cluster: "mainnet-beta", // For Ethereum, Phantom still uses this param
            redirectLink: context.redirectDeepLink
        ) else {
            completion(.failure(.connectionFailed("Failed to build connect URL")))
            return
        }
        
        // Store completion handler
        pendingConnectCompletion = completion
        
        // Start timeout
        startTimeout { [weak self] in
            self?.handleTimeout()
        }
        
        // Open Phantom
        print("🔗 Phantom: Opening connect URL: \(url)")
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }
    
    func disconnect() async throws {
        defer {
            // Clear session
            currentSession = nil
            phantomPublicKey = nil
            encryptionKeyPair = nil
            connectionState.send(.disconnected)
        }
        
        // Clear stored session
        try await sessionStorage.delete(for: walletType)
        
        // If we have a session, send disconnect to Phantom
        guard let session = currentSession,
              let keyPair = encryptionKeyPair,
              let phantomKey = phantomPublicKey else {
            return
        }
        
        do {
            // Create disconnect payload
            let payload = PhantomDisconnectPayload(session: session.sessionToken)
            let payloadData = try JSONEncoder().encode(payload)
            
            // Encrypt payload
            let encrypted = try PhantomEncryption.encrypt(
                plaintext: payloadData,
                recipientPublicKey: phantomPublicKey!,
                senderPrivateKey: keyPair.privateKey
            )
            
            // Build disconnect URL
            guard let url = PhantomDeepLinks.buildDisconnectURL(
                publicKey: Base58.encode(keyPair.publicKey),
                nonce: Base58.encode(encrypted.nonce),
                payload: Base58.encode(encrypted.ciphertext),
                redirectLink: WalletConnectionContext.default.redirectDeepLink
            ) else {
                return
            }
            
            // Open URL (fire and forget)
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        } catch {
            print("⚠️ Phantom: Disconnect error: \(error)")
        }
    }
    
    func signMessage(
        _ message: String,
        session: WalletSession,
        completion: @escaping (Result<WalletSignature, WalletError>) -> Void
    ) {
        guard session.walletType == .phantom,
              let sessionToken = session.sessionToken,
              let keyPair = encryptionKeyPair,
              phantomPublicKey != nil else {
            completion(.failure(.noSession))
            return
        }
        
        do {
            // Check if this is a SIWE message with Solana address
            if message.contains("wants you to sign in with your Ethereum account") &&
               session.address.count > 40 && !session.address.hasPrefix("0x") {
                print("⚠️ Phantom: Attempting to sign SIWE message with Solana address")
                print("⚠️ Phantom: Address format mismatch - Phantom deep links return Solana addresses")
                completion(.failure(.signatureFailed("Phantom deep links do not support Ethereum SIWE. Please use WalletConnect or a different wallet for Ethereum authentication.")))
                return
            }
            
            // Create sign message payload
            let payload = PhantomSignMessagePayload(
                message: message,
                session: sessionToken
            )
            let payloadData = try JSONEncoder().encode(payload)
            
            // Log payload details
            print("🔐 Phantom SignMessage: Message length: \(message.count)")
            print("🔐 Phantom SignMessage: Session token present: \(!sessionToken.isEmpty)")
            if let payloadString = String(data: payloadData, encoding: .utf8) {
                print("🔐 Phantom SignMessage: Payload JSON: \(payloadString)")
            }
            
            // Encrypt payload
            let encrypted = try PhantomEncryption.encrypt(
                plaintext: payloadData,
                recipientPublicKey: phantomPublicKey!,
                senderPrivateKey: keyPair.privateKey
            )
            
            // Build sign message URL
            guard let url = PhantomDeepLinks.buildSignMessageURL(
                publicKey: Base58.encode(keyPair.publicKey),
                nonce: Base58.encode(encrypted.nonce),
                payload: Base58.encode(encrypted.ciphertext),
                redirectLink: WalletConnectionContext.default.redirectDeepLink
            ) else {
                completion(.failure(.connectionFailed("Failed to build sign message URL")))
                return
            }
            
            // Log URL details
            print("🔐 Phantom SignMessage: URL: \(url.absoluteString)")
            print("🔐 Phantom SignMessage: Public key: \(Base58.encode(keyPair.publicKey))")
            print("🔐 Phantom SignMessage: Encrypted payload length: \(encrypted.ciphertext.count) bytes")
            
            // Store completion handler
            pendingSignMessageCompletion = { result in
                switch result {
                case .success(let signature):
                    let updatedSignature = WalletSignature(
                        signature: signature.signature,
                        address: signature.address,
                        message: message
                    )
                    completion(.success(updatedSignature))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
            // Start timeout
            startTimeout { [weak self] in
                self?.handleTimeout()
            }
            
            // Open Phantom
            print("🔐 Phantom: Opening sign message URL")
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
            
        } catch {
            completion(.failure(.signatureFailed(error.localizedDescription)))
        }
    }
    
    func signTransaction(
        _ transaction: WalletTransaction,
        session: WalletSession,
        completion: @escaping (Result<String, WalletError>) -> Void
    ) {
        guard session.walletType == .phantom,
              let sessionToken = session.sessionToken,
              let keyPair = encryptionKeyPair,
              phantomPublicKey != nil else {
            completion(.failure(.noSession))
            return
        }
        
        do {
            // For Ethereum transactions on Phantom, we need to convert to a format Phantom understands
            // Since Phantom is primarily a Solana wallet, we'll sign the transaction hash as a message
            let transactionHash = TransactionBuilder.createTransactionHash(transaction)
            let transactionHashHex = TransactionBuilder.dataToHex(transactionHash)
            
            // Create sign transaction payload (using message signing for now)
            let payload = PhantomSignMessagePayload(
                message: transactionHashHex,
                session: sessionToken
            )
            let payloadData = try JSONEncoder().encode(payload)
            
            // Encrypt payload
            let encrypted = try PhantomEncryption.encrypt(
                plaintext: payloadData,
                recipientPublicKey: phantomPublicKey!,
                senderPrivateKey: keyPair.privateKey
            )
            
            // Build sign URL
            guard let url = PhantomDeepLinks.buildSignMessageURL(
                publicKey: Base58.encode(keyPair.publicKey),
                nonce: Base58.encode(encrypted.nonce),
                payload: Base58.encode(encrypted.ciphertext),
                redirectLink: WalletConnectionContext.default.redirectDeepLink
            ) else {
                completion(.failure(.connectionFailed("Failed to build sign transaction URL")))
                return
            }
            
            // Store completion handler
            pendingSignTransactionCompletion = completion
            
            // Start timeout
            startTimeout { [weak self] in
                self?.handleTimeout()
            }
            
            // Open Phantom
            print("📝 Phantom: Opening sign transaction URL")
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
            
        } catch {
            completion(.failure(.signatureFailed(error.localizedDescription)))
        }
    }
    
    func sendTransaction(
        _ transaction: WalletTransaction,
        session: WalletSession,
        completion: @escaping (Result<String, WalletError>) -> Void
    ) {
        guard session.walletType == .phantom,
              let sessionToken = session.sessionToken,
              let keyPair = encryptionKeyPair,
              phantomPublicKey != nil else {
            completion(.failure(.noSession))
            return
        }
        
        // For Ethereum transactions, we would need a different approach
        // Since Phantom doesn't natively support Ethereum transaction sending via deep links,
        // we'll return an error for now
        completion(.failure(.connectionFailed("Ethereum transaction sending not supported via Phantom deep links. Use WalletConnect or in-app browser.")))
        
        // In a production app, you would either:
        // 1. Use WalletConnect for Ethereum transactions
        // 2. Open Phantom's in-app browser with the dApp
        // 3. Use a different wallet that supports Ethereum deep links
    }
    
    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        // Check if this is a Phantom callback
        guard url.scheme == "interspace",
              url.host == "wallet-callback" else {
            return false
        }
        
        // Parse response
        guard let response = PhantomDeepLinks.parseResponse(from: url) else {
            handleError(.connectionFailed("Invalid response"))
            return true
        }
        
        // Handle response based on type
        switch response {
        case .success(let nonce, let data, let publicKey):
            handleSuccessResponse(nonce: nonce, data: data, publicKey: publicKey)
        case .error(let code, let message):
            handleErrorResponse(code: code, message: message)
        }
        
        return true
    }
    
    // MARK: - Private Methods
    
    private func isPhantomInstalled() -> Bool {
        guard let url = URL(string: "phantom://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    private func restoreSession() async {
        do {
            if let session = try await sessionStorage.load(for: walletType) {
                currentSession = session
                connectionState.send(.connected(session))
                print("✅ Phantom: Restored session for \(session.address)")
            }
        } catch {
            print("⚠️ Phantom: Failed to restore session: \(error)")
        }
    }
    
    private func handleSuccessResponse(nonce: String, data: String, publicKey: String?) {
        cancelTimeout()
        
        print("🔐 Phantom: Processing success response")
        print("🔐 Phantom: Nonce length: \(nonce.count)")
        print("🔐 Phantom: Data length: \(data.count)")
        print("🔐 Phantom: Public key present: \(publicKey != nil)")
        
        // Decrypt the response
        guard let keyPair = encryptionKeyPair else {
            print("❌ Phantom: No encryption keypair available")
            handleError(.connectionFailed("No encryption keypair"))
            return
        }
        
        guard let nonceData = try? Base58.decode(nonce) else {
            print("❌ Phantom: Failed to decode nonce from Base58")
            handleError(.connectionFailed("Invalid nonce format"))
            return
        }
        
        guard let encryptedData = try? Base58.decode(data) else {
            print("❌ Phantom: Failed to decode data from Base58")
            handleError(.connectionFailed("Invalid data format"))
            return
        }
        
        print("🔐 Phantom: Decoded nonce length: \(nonceData.count) bytes")
        print("🔐 Phantom: Decoded data length: \(encryptedData.count) bytes")
        
        do {
            // For connect response, we need the Phantom public key
            if let publicKeyString = publicKey {
                print("🔐 Phantom: Processing connect response")
                
                let phantomPubKey = try Base58.decode(publicKeyString)
                phantomPublicKey = phantomPubKey
                
                print("🔐 Phantom: Phantom public key length: \(phantomPubKey.count) bytes")
                print("🔐 Phantom: Our private key length: \(keyPair.privateKey.count) bytes")
                
                // Decrypt connect response
                // Note: Phantom sends nonce and data separately, not combined
                let payload = PhantomEncryption.EncryptedPayload(
                    nonce: nonceData,
                    ciphertext: encryptedData
                )
                let decrypted = try PhantomEncryption.decrypt(
                    encryptedPayload: payload,
                    senderPublicKey: phantomPubKey,
                    recipientPrivateKey: keyPair.privateKey
                )
                
                print("🔐 Phantom: Decryption successful, response length: \(decrypted.count) bytes")
                
                let connectResponse = try JSONDecoder().decode(
                    PhantomConnectResponse.self,
                    from: decrypted
                )
                
                print("✅ Phantom: Connect response parsed successfully")
                handleConnectSuccess(response: connectResponse)
                
            } else if let phantomKey = phantomPublicKey {
                print("🔐 Phantom: Processing non-connect response")
                
                // Decrypt other responses (sign message, etc)
                // Note: Phantom sends nonce and data separately, not combined
                let payload = PhantomEncryption.EncryptedPayload(
                    nonce: nonceData,
                    ciphertext: encryptedData
                )
                let decrypted = try PhantomEncryption.decrypt(
                    encryptedPayload: payload,
                    senderPublicKey: phantomKey,
                    recipientPrivateKey: keyPair.privateKey
                )
                
                print("🔐 Phantom: Decryption successful, response length: \(decrypted.count) bytes")
                
                // Determine response type and handle accordingly
                if pendingSignMessageCompletion != nil {
                    let signResponse = try JSONDecoder().decode(
                        PhantomSignMessageResponse.self,
                        from: decrypted
                    )
                    handleSignMessageSuccess(response: signResponse)
                }
                // Add other response types as needed
            } else {
                print("❌ Phantom: No Phantom public key available for decryption")
                handleError(.connectionFailed("No Phantom public key available"))
            }
            
        } catch let decodingError as DecodingError {
            print("❌ Phantom: JSON decoding error: \(decodingError)")
            handleError(.connectionFailed("Invalid response format"))
        } catch let phantomError as PhantomError {
            print("❌ Phantom: Phantom error: \(phantomError)")
            handleError(.connectionFailed("Phantom error: \(phantomError.localizedDescription)"))
        } catch {
            print("❌ Phantom: Decryption error: \(error)")
            print("❌ Phantom: Error type: \(type(of: error))")
            handleError(.connectionFailed("Decryption failed: \(error.localizedDescription)"))
        }
    }
    
    private func handleErrorResponse(code: String, message: String) {
        cancelTimeout()
        
        let error: WalletError
        switch code {
        case "-32603": // User rejected
            error = .userCancelled
        case "-32600": // Invalid request
            error = .connectionFailed(message)
        default:
            error = .connectionFailed("\(code): \(message)")
        }
        
        handleError(error)
    }
    
    private func handleConnectSuccess(response: PhantomConnectResponse) {
        // Convert Solana address format to Ethereum if needed
        // For now, we'll use the public key as-is
        let address = response.publicKey
        
        // Create session
        let session = WalletSession(
            walletType: .phantom,
            address: address,
            chainId: 1, // Ethereum mainnet
            sessionToken: response.session,
            walletMetadata: WalletMetadata(
                name: "Phantom",
                icon: nil,
                version: nil
            ),
            connectedAt: Date(),
            additionalData: ["publicKey": response.publicKey]
        )
        
        // Update state
        currentSession = session
        connectionState.send(.connected(session))
        
        // Save session
        Task {
            try? await sessionStorage.save(session, for: walletType)
        }
        
        // Call completion
        pendingConnectCompletion?(.success(session))
        pendingConnectCompletion = nil
        
        print("✅ Phantom: Connected successfully to \(address)")
    }
    
    private func handleSignMessageSuccess(response: PhantomSignMessageResponse) {
        guard let session = currentSession else {
            handleError(.noSession)
            return
        }
        
        let signature = WalletSignature(
            signature: response.signature,
            address: session.address,
            message: "" // Will be updated by completion handler
        )
        
        pendingSignMessageCompletion?(.success(signature))
        pendingSignMessageCompletion = nil
        
        print("✅ Phantom: Message signed successfully")
    }
    
    private func handleError(_ error: WalletError) {
        // Update state
        connectionState.send(.error(error.localizedDescription))
        
        // Call appropriate completion handler
        if let completion = pendingConnectCompletion {
            completion(.failure(error))
            pendingConnectCompletion = nil
        } else if let completion = pendingSignMessageCompletion {
            completion(.failure(error))
            pendingSignMessageCompletion = nil
        } else if let completion = pendingSignTransactionCompletion {
            completion(.failure(error))
            pendingSignTransactionCompletion = nil
        } else if let completion = pendingSendTransactionCompletion {
            completion(.failure(error))
            pendingSendTransactionCompletion = nil
        }
    }
    
    private func handleTimeout() {
        print("⏱ Phantom: Request timed out")
        handleError(.timeout())
    }
    
    private func startTimeout(handler: @escaping () -> Void) {
        cancelTimeout()
        timeoutTimer = Timer.scheduledTimer(
            withTimeInterval: requestTimeout,
            repeats: false
        ) { _ in
            handler()
        }
    }
    
    private func cancelTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
    
    private func cancelPendingOperations() {
        cancelTimeout()
        
        // Clear all pending completions
        pendingConnectCompletion = nil
        pendingSignMessageCompletion = nil
        pendingSignTransactionCompletion = nil
        pendingSendTransactionCompletion = nil
    }
}

