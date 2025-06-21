import SwiftUI

struct WalletConnectionTray: View {
    @Binding var isPresented: Bool
    var isForAuthentication: Bool = false
    @ObservedObject var authViewModel: AuthViewModel  // For authentication flow
    @ObservedObject private var profileViewModel = ProfileViewModel.shared  // For profile linking flow
    
    @State private var selectedWallet: WalletType?
    @State private var showWalletConnection = false
    
    private let wallets: [(type: WalletType, available: Bool)] = [
        (.metamask, true),
        (.coinbase, true),
        (.walletConnect, true),
        (.safe, false),
        (.ledger, false)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                DesignTokens.Colors.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isForAuthentication ? "Connect Wallet" : "Add Wallet")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            
                            Text(isForAuthentication ? 
                                 "Sign in with your crypto wallet" : 
                                 "Connect a wallet to your profile")
                                .font(.body)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Available Wallets Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Available Wallets")
                                .font(.headline)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                ForEach(wallets.filter { $0.available }, id: \.type) { wallet in
                                    TrayWalletOptionRow(
                                        walletType: wallet.type,
                                        title: wallet.type.displayName,
                                        subtitle: subtitle(for: wallet.type),
                                        isFirst: wallet.type == wallets.filter { $0.available }.first?.type,
                                        isLast: wallet.type == wallets.filter { $0.available }.last?.type,
                                        onTap: {
                                            selectedWallet = wallet.type
                                            showWalletConnection = true
                                        }
                                    )
                                    
                                    if wallet.type != wallets.filter { $0.available }.last?.type {
                                        Divider()
                                            .padding(.leading, 72)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(DesignTokens.Colors.backgroundSecondary)
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        // Coming Soon Section
                        if wallets.contains(where: { !$0.available }) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Coming Soon")
                                    .font(.headline)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                    .padding(.horizontal, 20)
                                
                                VStack(spacing: 0) {
                                    ForEach(wallets.filter { !$0.available }, id: \.type) { wallet in
                                        ComingSoonWalletRow(
                                            walletType: wallet.type,
                                            title: wallet.type.displayName,
                                            subtitle: subtitle(for: wallet.type),
                                            isFirst: wallet.type == wallets.filter { !$0.available }.first?.type,
                                            isLast: wallet.type == wallets.filter { !$0.available }.last?.type
                                        )
                                        
                                        if wallet.type != wallets.filter { !$0.available }.last?.type {
                                            Divider()
                                                .padding(.leading, 72)
                                        }
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(DesignTokens.Colors.backgroundSecondary)
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Info Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label {
                                Text("Your keys, your crypto")
                                    .font(.caption)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                            } icon: {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.green)
                            }
                            
                            Label {
                                Text("Connect multiple wallets to one profile")
                                    .font(.caption)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                            } icon: {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                            
                            Label {
                                Text("Switch between profiles seamlessly")
                                    .font(.caption)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                            } icon: {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(DesignTokens.Colors.backgroundSecondary.opacity(0.5))
                        )
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .background(Circle().fill(DesignTokens.Colors.backgroundSecondary))
                    }
                }
            }
        }
        .sheet(item: $selectedWallet) { walletType in
            WalletConnectionView(
                walletType: walletType,
                viewModel: profileViewModel,
                onComplete: {
                    showWalletConnection = false
                    selectedWallet = nil
                    isPresented = false
                },
                isForAuthentication: isForAuthentication
            )
        }
    }
    
    private func subtitle(for walletType: WalletType) -> String {
        switch walletType {
        case .metamask:
            return "Connect your MetaMask wallet"
        case .coinbase:
            return "Connect your Coinbase wallet"
        case .walletConnect:
            return "Connect any WalletConnect wallet"
        case .safe:
            return "Multi-signature wallet support"
        case .ledger:
            return "Hardware wallet integration"
        default:
            return "Connect your wallet"
        }
    }
}

// MARK: - Tray Wallet Option Row

struct TrayWalletOptionRow: View {
    let walletType: WalletType
    let title: String
    let subtitle: String
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            onTap()
        }) {
            HStack(spacing: 16) {
                // Wallet Icon
                Image(walletType.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(walletType.primaryColor.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Coming Soon Wallet Row

struct ComingSoonWalletRow: View {
    let walletType: WalletType
    let title: String
    let subtitle: String
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Wallet Icon
            Image(walletType.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignTokens.Colors.textTertiary.opacity(0.1))
                )
                .opacity(0.5)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary.opacity(0.7))
            }
            
            Spacer()
            
            Text("Soon")
                .font(.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(DesignTokens.Colors.textTertiary.opacity(0.1))
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .opacity(0.6)
    }
}

// MARK: - Helpers

extension WalletType {
    var iconName: String {
        switch self {
        case .metamask:
            return "metamask"
        case .coinbase:
            return "coinbase"
        default:
            return "wallet"
        }
    }
    
    var deepLink: String {
        switch self {
        case .metamask:
            return "metamask://"
        case .coinbase:
            return "cbwallet://"
        default:
            return ""
        }
    }
    
    func openWalletApp() {
        guard let url = URL(string: deepLink) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

struct WalletConnectionTray_Previews: PreviewProvider {
    static var previews: some View {
        WalletConnectionTray(
            isPresented: .constant(true),
            isForAuthentication: true,
            authViewModel: AuthViewModel()
        )
        .preferredColorScheme(.dark)
    }
}