import Foundation

// WalletConnect notification names
extension Notification.Name {
    // Defined in WalletConnectService.swift: static let linkModeResponse
    static let walletConnectCallback = Notification.Name("walletConnectCallback")
    static let linkModeAuthCompleted = Notification.Name("linkModeAuthCompleted") 
    static let clearWalletConnections = Notification.Name("clearWalletConnections")
}
