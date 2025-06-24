import SwiftUI

// MARK: - Add Tray Row Component
struct AddTrayRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    var customIcon: Image? = nil
    var showDisclosure: Bool = true
    var showActivity: Bool = false
    var isHighlighted: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    if let customIcon = customIcon {
                        customIcon
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(iconColor)
                    }
                }
                
                // Title
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Right accessory
                if showActivity {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if showDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.tertiaryLabel)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isHighlighted ? Color.blue.opacity(0.08) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Wallet Selection View
struct WalletSelectionView: View {
    let wallets: [WalletType] = [.metamask, .coinbase, .walletConnect]
    let onSelect: (WalletType) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(wallets, id: \.self) { wallet in
                            AddTrayRow(
                                icon: wallet.systemIconName,
                                title: wallet.displayName,
                                iconColor: wallet.primaryColor,
                                action: {
                                    onSelect(wallet)
                                }
                            )
                            
                            if wallet != wallets.last {
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .cornerRadius(12)
                    .padding()
                }
            }
            .navigationTitle("Select Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: 
                Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Social Selection View
struct SocialSelectionView: View {
    let providers: [SocialProvider] = [.google, .apple, .telegram, .farcaster]
    let onSelect: (SocialProvider) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(providers, id: \.self) { provider in
                            AddTrayRow(
                                icon: provider.iconName,
                                title: provider.displayName,
                                iconColor: provider.color,
                                action: {
                                    onSelect(provider)
                                }
                            )
                            
                            if provider != providers.last {
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .cornerRadius(12)
                    .padding()
                }
            }
            .navigationTitle("Connect Social Account")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: 
                Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
}

// MARK: - App Selection View
struct AppSelectionView: View {
    @State private var url: String = ""
    @State private var isValidURL = false
    let onAdd: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // URL Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Website URL")
                            .font(.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        
                        TextField("https://example.com", text: $url)
                            .textFieldStyle(LiquidGlassTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: url) { newValue in
                                validateURL(newValue)
                            }
                    }
                    .padding(.horizontal)
                    
                    // Popular Apps
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Popular Apps")
                            .font(.headline)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            PopularAppRow(name: "Uniswap", url: "https://app.uniswap.org", icon: "arrow.triangle.swap") {
                                if let url = URL(string: "https://app.uniswap.org") {
                                    onAdd(url)
                                }
                            }
                            
                            Divider()
                                .padding(.leading, 76)
                            
                            PopularAppRow(name: "OpenSea", url: "https://opensea.io", icon: "photo.artframe") {
                                if let url = URL(string: "https://opensea.io") {
                                    onAdd(url)
                                }
                            }
                            
                            Divider()
                                .padding(.leading, 76)
                            
                            PopularAppRow(name: "Aave", url: "https://app.aave.com", icon: "chart.line.uptrend.xyaxis") {
                                if let url = URL(string: "https://app.aave.com") {
                                    onAdd(url)
                                }
                            }
                        }
                        .background(DesignTokens.Colors.backgroundSecondary)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Add Button
                    Button(action: {
                        if let url = URL(string: url), isValidURL {
                            onAdd(url)
                        }
                    }) {
                        Text("Add App")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValidURL ? DesignTokens.Colors.primary : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!isValidURL)
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .navigationTitle("Add App")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: 
                Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
    
    private func validateURL(_ urlString: String) {
        if let url = URL(string: urlString),
           let scheme = url.scheme,
           ["http", "https"].contains(scheme),
           url.host != nil {
            isValidURL = true
        } else {
            isValidURL = false
        }
    }
}

// MARK: - Popular App Row
struct PopularAppRow: View {
    let name: String
    let url: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            AddTrayRow(
                icon: icon,
                title: name,
                iconColor: .blue,
                action: action
            )
        }
    }
}

// MARK: - Contact Selection View
struct ContactSelectionView: View {
    @State private var searchText = ""
    let onSelect: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        
                        TextField("Search contacts", text: $searchText)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                    }
                    .padding(12)
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .cornerRadius(10)
                    .padding()
                    
                    // Placeholder
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 60))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                        
                        Text("Contact management coming soon")
                            .font(.headline)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        
                        Text("You'll be able to save and manage crypto contacts here")
                            .font(.caption)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: 
                Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
}