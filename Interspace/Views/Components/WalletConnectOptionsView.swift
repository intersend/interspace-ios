import SwiftUI

struct WalletConnectOptionsView: View {
    @Binding var isPresented: Bool
    let onWalletSelected: (String?) -> Void
    
    @State private var availableWallets: [WalletAppInfo] = []
    @State private var generatedURI: String?
    @State private var isGeneratingURI = false
    
    private let walletService = WalletService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Connect Wallet")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose a wallet app or scan the QR code")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Available Wallet Apps
                        if !availableWallets.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Available Wallets")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                
                                VStack(spacing: 0) {
                                    ForEach(Array(availableWallets.enumerated()), id: \.element.scheme) { index, wallet in
                                        WalletAppRow(
                                            wallet: wallet,
                                            isFirst: index == 0,
                                            isLast: index == availableWallets.count - 1
                                        ) {
                                            onWalletSelected(wallet.scheme)
                                        }
                                        
                                        if index < availableWallets.count - 1 {
                                            Divider()
                                                .padding(.leading, 72)
                                        }
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(white: 0.15))
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // QR Code Option
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Or Use QR Code")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                            
                            Button(action: {
                                onWalletSelected(nil)
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "qrcode")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .frame(width: 48, height: 48)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.purple)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Scan QR Code")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                        
                                        Text("Use any WalletConnect compatible wallet")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(white: 0.15))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, availableWallets.isEmpty ? 0 : 24)
                        
                        // Not Installed Section
                        if availableWallets.count < 5 { // Assuming we support 5 wallet apps
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Get a Wallet")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                
                                HStack {
                                    Text("Download a wallet app from the App Store")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        if let url = URL(string: "https://apps.apple.com/search?term=ethereum+wallet") {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        Text("Browse")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.top, 24)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .background(Color.black.opacity(0.001))
            .background(Material.regularMaterial)
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            checkAvailableWallets()
        }
    }
    
    private func checkAvailableWallets() {
        availableWallets = walletService.getAvailableWalletApps()
    }
}

struct WalletAppRow: View {
    let wallet: WalletAppInfo
    let isFirst: Bool
    let isLast: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Wallet Icon
                Image(systemName: walletIconName)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(walletColor)
                    )
                
                Text(wallet.name)
                    .font(.body)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var walletIconName: String {
        switch wallet.scheme {
        case "metamask":
            return "fox"
        case "rainbow":
            return "rainbow"
        case "trust":
            return "shield.fill"
        case "argent":
            return "a.circle.fill"
        case "gnosissafe":
            return "shield.checkered"
        default:
            return "wallet.pass"
        }
    }
    
    private var walletColor: Color {
        switch wallet.scheme {
        case "metamask":
            return .orange
        case "rainbow":
            return Color(red: 0.4, green: 0.6, blue: 1.0)
        case "trust":
            return Color(red: 0.2, green: 0.6, blue: 1.0)
        case "argent":
            return Color(red: 1.0, green: 0.5, blue: 0.2)
        case "gnosissafe":
            return .green
        default:
            return .purple
        }
    }
}

struct WalletConnectOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        WalletConnectOptionsView(isPresented: .constant(true)) { _ in }
            .preferredColorScheme(.dark)
    }
}