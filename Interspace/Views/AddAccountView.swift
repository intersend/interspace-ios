import SwiftUI

struct AddAccountView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWalletType: WalletType?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background - slightly lighter for tray distinction
                Color(white: 0.08)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add Wallet Account")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Connect your crypto wallets to manage assets and interact with dApps.")
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Available Wallets Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Available Wallets")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                // MetaMask
                                WalletOptionRow(
                                    walletType: .metamask,
                                    title: "MetaMask",
                                    subtitle: "Connect your MetaMask wallet",
                                    isFirst: true,
                                    isLast: false,
                                    onTap: {
                                        HapticManager.impact(.light)
                                        selectedWalletType = .metamask
                                    }
                                )
                                
                                Divider()
                                    .padding(.leading, 72)
                                
                                // Coinbase Wallet
                                WalletOptionRow(
                                    walletType: .coinbase,
                                    title: "Coinbase Wallet",
                                    subtitle: "Connect your Coinbase wallet",
                                    isFirst: false,
                                    isLast: false,
                                    onTap: {
                                        HapticManager.impact(.light)
                                        selectedWalletType = .coinbase
                                    }
                                )
                                
                                Divider()
                                    .padding(.leading, 72)
                                
                                // WalletConnect
                                WalletOptionRow(
                                    walletType: .walletConnect,
                                    title: "WalletConnect",
                                    subtitle: "Connect any WalletConnect wallet",
                                    isFirst: false,
                                    isLast: true,
                                    onTap: {
                                        HapticManager.impact(.light)
                                        selectedWalletType = .walletConnect
                                    }
                                )
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(white: 0.15))
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        // Coming Soon Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Coming Soon")
                                .font(.headline)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                ComingSoonRow(
                                    icon: "wallet.pass",
                                    title: "Hardware Wallets",
                                    subtitle: "Ledger, Trezor support",
                                    isFirst: true,
                                    isLast: false
                                )
                                
                                Divider()
                                    .padding(.leading, 72)
                                
                                ComingSoonRow(
                                    icon: "iphone",
                                    title: "Mobile Wallets",
                                    subtitle: "Trust, Rainbow support",
                                    isFirst: false,
                                    isLast: true
                                )
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(white: 0.15))
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(Color(white: 0.15))
                            )
                    }
                }
            }
        }
        .sheet(item: $selectedWalletType) { walletType in
            WalletConnectionView(
                walletType: walletType,
                viewModel: viewModel,
                onComplete: {
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Wallet Option Row

struct WalletOptionRow: View {
    let walletType: WalletType
    let title: String
    let subtitle: String
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Wallet Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(walletType.primaryColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: walletType.systemIconName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(walletType.primaryColor)
                }
                
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

// MARK: - Coming Soon Row

struct ComingSoonRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignTokens.Colors.textTertiary.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            
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
                .foregroundColor(.gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.1))
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .opacity(0.6)
    }
}

// MARK: - Preview

struct AddAccountView_Previews: PreviewProvider {
    static var previews: some View {
        AddAccountView(viewModel: ProfileViewModel.shared)
            .preferredColorScheme(.dark)
    }
}