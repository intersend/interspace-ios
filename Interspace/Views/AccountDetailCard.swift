import SwiftUI

struct AccountDetailCard: View {
    let account: LinkedAccount
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var dragOffset = CGSize.zero
    @State private var cardScale: CGFloat = 0.9
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Card
            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                
                // Card Content
                VStack(spacing: 24) {
                    // Wallet Type Icon
                    ZStack {
                        Circle()
                            .fill(walletColor(for: account.walletType ?? "").opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: walletIcon(for: account.walletType ?? ""))
                            .font(.system(size: 36))
                            .foregroundColor(walletColor(for: account.walletType ?? ""))
                    }
                    
                    // Account Name
                    VStack(spacing: 8) {
                        Text(account.displayName)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if account.isPrimary {
                            Label("Primary Account", systemImage: "star.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    // Wallet Address
                    VStack(spacing: 12) {
                        Text("Wallet Address")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(account.address)
                            .font(.system(size: 15, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        Button(action: {
                            UIPasteboard.general.string = account.address
                            // Haptic feedback
                        }) {
                            Label("Copy Address", systemImage: "doc.on.doc")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(DesignTokens.Colors.primary)
                        }
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    // Actions
                    VStack(spacing: 12) {
                        if !account.isPrimary {
                            Button(action: {
                                Task {
                                    await viewModel.setPrimaryAccount(account)
                                    dismiss()
                                }
                            }) {
                                Label("Set as Primary", systemImage: "star")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(DesignTokens.Colors.primary)
                                    .cornerRadius(14)
                            }
                        }
                        
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Label("Remove Account", systemImage: "trash")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.red.opacity(0.15))
                                .cornerRadius(14)
                        }
                    }
                }
                .padding(24)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.systemGray6))
                    .background(Material.regular)
                    .cornerRadius(24)
            )
            .scaleEffect(cardScale)
            .offset(y: max(0, dragOffset.height))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            if value.translation.height > 100 {
                                dismiss()
                            } else {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    cardScale = 1.0
                }
            }
        }
        .alert("Remove Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task {
                    await viewModel.unlinkAccount(account)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to remove this account? This action cannot be undone.")
        }
    }
    
    // MARK: - Helper Functions
    
    private func walletIcon(for type: String) -> String {
        switch WalletType(rawValue: type) {
        case .metamask:
            return "fox.fill"
        case .coinbase:
            return "c.square.fill"
        case .walletConnect:
            return "link"
        case .ledger:
            return "square.stack.3d.up.fill"
        case .safe:
            return "shield.checkered"
        default:
            return "wallet.pass.fill"
        }
    }
    
    private func walletColor(for type: String) -> Color {
        switch WalletType(rawValue: type) {
        case .metamask:
            return .orange
        case .coinbase:
            return .blue
        case .walletConnect:
            return .blue
        case .ledger:
            return .black
        case .safe:
            return .green
        default:
            return .gray
        }
    }
}