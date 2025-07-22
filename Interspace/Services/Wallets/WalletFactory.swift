import Foundation
import UIKit
import CoinbaseWalletSDK

/// Factory for creating wallet service instances
final class WalletFactory: WalletFactoryProtocol {
    
    // MARK: - Singleton
    
    static let shared = WalletFactory()
    
    // MARK: - Properties
    
    private let sessionStorage: WalletSessionStorageProtocol
    
    // Cached wallet instances
    private var walletInstances: [WalletType: WalletProtocol] = [:]
    private let instanceQueue = DispatchQueue(label: "com.interspace.wallet.factory", attributes: .concurrent)
    
    // MARK: - Initialization
    
    init(sessionStorage: WalletSessionStorageProtocol = WalletSessionStorage.shared) {
        self.sessionStorage = sessionStorage
    }
    
    // MARK: - WalletFactoryProtocol
    
    func createWallet(for type: WalletType) -> WalletProtocol? {
        print("🏭 WalletFactory: createWallet called for type: \(type.displayName)")
        
        // Check cache first
        if let cached = getCachedWallet(for: type) {
            print("🏭 WalletFactory: Returning cached instance for \(type.displayName)")
            return cached
        }
        
        print("🏭 WalletFactory: Creating new instance for \(type.displayName)")
        
        // Create new instance
        let wallet: WalletProtocol?
        
        switch type {
        case .phantom:
            // Use Reown for Phantom Ethereum support
            wallet = ReownWalletService(walletType: type)
            
        case .metamask:
            // Use native MetaMask SDK for better UX
            wallet = MetaMaskService(sessionStorage: sessionStorage)
            
        case .rainbow:
            wallet = ReownWalletService(walletType: type)
            
        case .trust:
            wallet = ReownWalletService(walletType: type)
            
        case .argent:
            wallet = ReownWalletService(walletType: type)
            
        case .coinbase:
            // Use native Coinbase SDK for better UX
            print("🏭 WalletFactory: Creating Coinbase wallet...")
            
            // Check if CoinbaseWalletSDK is available
            #if canImport(CoinbaseWalletSDK)
                print("🏭 WalletFactory: CoinbaseWalletSDK package is installed ✓")
                // Use native CoinbaseService if SDK is available
                wallet = CoinbaseService(sessionStorage: sessionStorage)
                print("🏭 WalletFactory: Coinbase wallet created successfully")
            #else
                print("❌ WalletFactory: CoinbaseWalletSDK package not installed")
                print("❌ WalletFactory: Add package: https://github.com/MobileWalletProtocol/wallet-mobile-sdk")
                wallet = ReownWalletService(walletType: type)
            #endif
            
            if let wallet = wallet {
                print("🏭 WalletFactory: Created wallet type: \(Swift.type(of: wallet))")
            } else {
                print("🏭 WalletFactory: Failed to create wallet")
            }
            
        default:
            // Wallet not yet implemented
            print("⚠️ WalletFactory: Wallet type \(type.displayName) not implemented yet")
            wallet = nil
        }
        
        // Cache the instance if created
        if let wallet = wallet {
            cacheWallet(wallet, for: type)
        }
        
        return wallet
    }
    
    func isSupported(_ type: WalletType) -> Bool {
        // List of currently supported wallets
        switch type {
        case .phantom, .metamask, .rainbow, .trust, .argent, .coinbase:
            return true
        default:
            return false
        }
    }
    
    var supportedWallets: [WalletType] {
        WalletType.allCases.filter { isSupported($0) }
    }
    
    // MARK: - Cache Management
    
    private func getCachedWallet(for type: WalletType) -> WalletProtocol? {
        instanceQueue.sync {
            walletInstances[type]
        }
    }
    
    private func cacheWallet(_ wallet: WalletProtocol, for type: WalletType) {
        instanceQueue.async(flags: .barrier) {
            self.walletInstances[type] = wallet
        }
    }
    
    /// Clear all cached wallet instances
    func clearCache() {
        instanceQueue.async(flags: .barrier) {
            self.walletInstances.removeAll()
        }
    }
    
    /// Get or create wallet instance
    func wallet(for type: WalletType) -> WalletProtocol? {
        createWallet(for: type)
    }
}

// MARK: - Wallet Factory Extensions

extension WalletFactory {
    /// Check if a wallet app is installed
    func isWalletInstalled(_ type: WalletType) -> Bool {
        guard let scheme = walletURLScheme(for: type),
              let url = URL(string: "\(scheme)://") else {
            return false
        }
        return UIApplication.shared.canOpenURL(url)
    }
    
    /// Get URL scheme for wallet type
    private func walletURLScheme(for type: WalletType) -> String? {
        switch type {
        case .phantom:
            return "phantom"
        case .trust:
            return "trust"
        case .rainbow:
            return "rainbow"
        case .argent:
            return "argent"
        case .family:
            return "familywallet"
        case .oneInch:
            return "oneinch"
        case .zerion:
            return "zerion"
        case .imToken:
            return "imtoken"
        case .tokenPocket:
            return "tokenpocket"
        case .spot:
            return "spot"
        case .omni:
            return "omni"
        case .gnosisSafe:
            return "gnosissafe"
        case .metamask:
            return "metamask"
        case .coinbase:
            return "cbwallet"
        default:
            return nil
        }
    }
}

