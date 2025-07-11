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
    case family = "family"
    case phantom = "phantom"
    case oneInch = "oneinch"
    case zerion = "zerion"
    case imToken = "imtoken"
    case tokenPocket = "tokenpocket"
    case spot = "spot"
    case omni = "omni"
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
        case .family:
            return "Family"
        case .phantom:
            return "Phantom"
        case .oneInch:
            return "1inch Wallet"
        case .zerion:
            return "Zerion"
        case .imToken:
            return "imToken"
        case .tokenPocket:
            return "TokenPocket"
        case .spot:
            return "Spot"
        case .omni:
            return "Omni"
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
        case .family:
            return "person.2.fill"
        case .phantom:
            return "moon.fill"
        case .oneInch:
            return "1.circle.fill"
        case .zerion:
            return "z.circle.fill"
        case .imToken:
            return "square.and.arrow.up.fill"
        case .tokenPocket:
            return "folder.fill"
        case .spot:
            return "location.fill"
        case .omni:
            return "infinity"
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
        case .family:
            return "family"
        case .phantom:
            return "phantom"
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
        case .family:
            return Color(red: 0.5, green: 0.8, blue: 0.4)
        case .phantom:
            return Color(red: 0.4, green: 0.3, blue: 0.9)
        case .oneInch:
            return Color(red: 0.9, green: 0.2, blue: 0.3)
        case .zerion:
            return Color(red: 0.2, green: 0.7, blue: 0.9)
        case .imToken:
            return Color(red: 0.1, green: 0.5, blue: 0.9)
        case .tokenPocket:
            return Color(red: 0.3, green: 0.7, blue: 0.5)
        case .spot:
            return Color(red: 0.9, green: 0.6, blue: 0.2)
        case .omni:
            return Color(red: 0.6, green: 0.2, blue: 0.8)
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
    
    var deepLinkScheme: String {
        switch self {
        case .metamask:
            return "metamask"
        case .coinbase:
            return "cbwallet"
        case .walletConnect:
            return "wc"
        case .rainbow:
            return "rainbow"
        case .trust:
            return "trust"
        case .argent:
            return "argent"
        case .gnosisSafe:
            return "gnosissafe"
        case .family:
            return "familywallet"
        case .phantom:
            return "phantom"
        case .oneInch:
            return "oneinch"
        case .zerion:
            return "zerion"
        case .imToken:
            return "imtoken"
        case .tokenPocket:
            return "tpoutside"
        case .spot:
            return "spot"
        case .omni:
            return "omni"
        case .safe:
            return "safe"
        case .ledger:
            return "ledgerlive"
        case .trezor:
            return "trezor"
        case .google:
            return "google"
        case .apple:
            return "apple"
        case .mpc:
            return "mpc"
        case .unknown:
            return "unknown"
        }
    }
    
    var appStoreURL: URL? {
        switch self {
        case .metamask:
            return URL(string: "https://apps.apple.com/app/metamask/id1438144202")
        case .coinbase:
            return URL(string: "https://apps.apple.com/app/coinbase-wallet/id1278383455")
        case .walletConnect:
            return nil
        case .rainbow:
            return URL(string: "https://apps.apple.com/app/rainbow-ethereum-wallet/id1457119021")
        case .trust:
            return URL(string: "https://apps.apple.com/app/trust-crypto-bitcoin-wallet/id1288339409")
        case .argent:
            return URL(string: "https://apps.apple.com/app/argent/id1358741926")
        case .gnosisSafe:
            return URL(string: "https://apps.apple.com/app/gnosis-safe/id1515759131")
        case .family:
            return URL(string: "https://apps.apple.com/app/family-wallet/id1644169549")
        case .phantom:
            return URL(string: "https://apps.apple.com/app/phantom-crypto-wallet/id1598432977")
        case .oneInch:
            return URL(string: "https://apps.apple.com/app/1inch-defi-wallet/id1546049391")
        case .zerion:
            return URL(string: "https://apps.apple.com/app/zerion-wallet/id1456732565")
        case .imToken:
            return URL(string: "https://apps.apple.com/app/imtoken/id1384798940")
        case .tokenPocket:
            return URL(string: "https://apps.apple.com/app/tokenpocket/id1436028697")
        case .spot:
            return URL(string: "https://apps.apple.com/app/spot-wallet/id1567759439")
        case .omni:
            return URL(string: "https://apps.apple.com/app/omni/id1569088095")
        case .safe:
            return URL(string: "https://apps.apple.com/app/safe/id1515759131")
        case .ledger:
            return URL(string: "https://apps.apple.com/app/ledger-live/id1361671700")
        case .trezor:
            return URL(string: "https://apps.apple.com/app/trezor-suite/id1631884497")
        case .google, .apple, .mpc, .unknown:
            return nil
        }
    }
}