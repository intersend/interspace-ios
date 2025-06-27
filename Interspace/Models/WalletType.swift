import Foundation
import SwiftUI

// MARK: - WalletAppInfo
struct WalletAppInfo {
    let name: String
    let scheme: String
    let icon: String
}

enum WalletType: String, Codable, CaseIterable, Identifiable {
    case metamask = "metamask"
    case coinbase = "coinbase"
    case walletConnect = "walletconnect"
    case rainbow = "rainbow"
    case trust = "trust"
    case argent = "argent"
    case gnosisSafe = "gnosissafe"
    case safe = "safe"
    case ledger = "ledger"
    case trezor = "trezor"
    case google = "google"
    case apple = "apple"
    case mpc = "mpc"
    case unknown = "unknown"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .metamask:
            return "MetaMask"
        case .coinbase:
            return "Coinbase Wallet"
        case .walletConnect:
            return "WalletConnect"
        case .rainbow:
            return "Rainbow"
        case .trust:
            return "Trust Wallet"
        case .argent:
            return "Argent"
        case .gnosisSafe:
            return "Gnosis Safe"
        case .safe:
            return "Safe"
        case .ledger:
            return "Ledger"
        case .trezor:
            return "Trezor"
        case .google:
            return "Google"
        case .apple:
            return "Apple"
        case .mpc:
            return "MPC Wallet"
        case .unknown:
            return "Unknown"
        }
    }
    
    var systemIconName: String {
        switch self {
        case .metamask:
            return "fox"
        case .coinbase:
            return "c.circle.fill"
        case .walletConnect:
            return "link.circle.fill"
        case .rainbow:
            return "rainbow"
        case .trust:
            return "shield.fill"
        case .argent:
            return "a.circle.fill"
        case .gnosisSafe:
            return "shield.checkered"
        case .safe:
            return "shield.fill"
        case .ledger:
            return "rectangle.connected.to.line.below"
        case .trezor:
            return "lock.shield.fill"
        case .google:
            return "g.circle"
        case .apple:
            return "apple.logo"
        case .mpc:
            return "lock.shield.fill"
        case .unknown:
            return "wallet.pass"
        }
    }
    
    var icon: String {
        switch self {
        case .metamask:
            return "metamask"
        case .coinbase:
            return "coinbase"
        case .walletConnect:
            return "walletconnect"
        case .rainbow:
            return "rainbow"
        case .trust:
            return "trust"
        case .argent:
            return "argent"
        case .gnosisSafe:
            return "gnosissafe"
        case .safe:
            return "safe"
        case .ledger:
            return "ledger"
        case .trezor:
            return "trezor"
        case .google:
            return "google"
        case .apple:
            return "apple"
        case .mpc:
            return "mpc"
        case .unknown:
            return "wallet"
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .metamask:
            return DesignTokens.Colors.metamask
        case .coinbase:
            return DesignTokens.Colors.coinbase
        case .walletConnect:
            return Color.blue
        case .rainbow:
            return Color(red: 0.4, green: 0.6, blue: 1.0)
        case .trust:
            return Color(red: 0.2, green: 0.6, blue: 1.0)
        case .argent:
            return Color(red: 1.0, green: 0.5, blue: 0.2)
        case .gnosisSafe:
            return Color.green
        case .safe:
            return Color.green
        case .ledger:
            return Color.black
        case .trezor:
            return Color.red
        case .google:
            return DesignTokens.Colors.google
        case .apple:
            return DesignTokens.Colors.apple
        case .mpc:
            return DesignTokens.Colors.primary
        case .unknown:
            return DesignTokens.Colors.primary
        }
    }
}