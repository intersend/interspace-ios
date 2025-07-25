import SwiftUI

// TokenBalance and ChainBalance type aliases are defined in WalletModels.swift

struct TokenSelectionView: View {
    @Binding var selectedToken: TokenBalance?
    @Binding var selectedChainId: Int?
    let tokens: [TokenBalance]
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var showOnlyWithBalance = true
    @FocusState private var isSearchFocused: Bool
    
    private var filteredTokens: [TokenBalance] {
        tokens
            .filter { token in
                // Filter by balance if enabled
                if showOnlyWithBalance && token.totalBalance <= 0 {
                    return false
                }
                
                // Filter by search text
                if !searchText.isEmpty {
                    let searchLower = searchText.lowercased()
                    return token.symbol.lowercased().contains(searchLower) ||
                           token.name.lowercased().contains(searchLower)
                }
                
                return true
            }
            .sorted { $0.totalBalanceUSD > $1.totalBalanceUSD }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Search Bar
                        searchBar
                            .padding(.horizontal, DesignTokens.Spacing.screen)
                            .padding(.vertical, DesignTokens.Spacing.regular)
                        
                        // Balance Filter Toggle
                        balanceFilterToggle
                            .padding(.horizontal, DesignTokens.Spacing.screen)
                            .padding(.bottom, DesignTokens.Spacing.regular)
                        
                        // Token List
                        if filteredTokens.isEmpty {
                            emptyState
                        } else {
                            tokenList
                        }
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Select Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: DesignTokens.Spacing.tight) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))
                .font(.system(size: 16))
            
            TextField("Search tokens", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .focused($isSearchFocused)
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.regular)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    private var balanceFilterToggle: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showOnlyWithBalance.toggle()
                HapticManager.shared.impact(style: .light)
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.tight) {
                Image(systemName: showOnlyWithBalance ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(showOnlyWithBalance ? DesignTokens.Colors.Brand.primary : .white.opacity(0.5))
                    .font(.system(size: 20))
                
                Text("Show only tokens with balance")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.regular)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    private var tokenList: some View {
        LazyVStack(spacing: DesignTokens.Spacing.tight) {
            ForEach(filteredTokens, id: \.id) { token in
                TokenSelectionRow(
                    token: token,
                    isSelected: selectedToken?.id == token.id,
                    onSelect: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedToken = token
                            // Auto-select chain with highest balance
                            if let chainBalance = token.chainBalances.max(by: { $0.balanceUSD < $1.balanceUSD }) {
                                selectedChainId = chainBalance.chainId
                            }
                            HapticManager.shared.impact(style: .light)
                            dismiss()
                        }
                    }
                )
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.screen)
        .padding(.bottom, DesignTokens.Spacing.section)
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.loose) {
            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            
            Text(searchText.isEmpty ? "No tokens with balance" : "No tokens found")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            if !searchText.isEmpty {
                Text("Try searching with a different term")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))
            } else if showOnlyWithBalance {
                Button {
                    showOnlyWithBalance = false
                } label: {
                    Text("Show all tokens")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.Brand.primary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

struct TokenSelectionRow: View {
    let token: TokenBalance
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Main row
                HStack(spacing: DesignTokens.Spacing.regular) {
                    // Token icon
                    TokenIcon(symbol: token.symbol)
                        .frame(width: 48, height: 48)
                    
                    // Token info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(token.symbol)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                            
                            if token.chainBalances.count > 1 {
                                Text("\(token.chainBalances.count)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.15))
                                    )
                            }
                        }
                        
                        Text(token.name)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Balance
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(WalletDesignSystem.formatCurrency(token.totalBalanceUSD))
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                        
                        if token.totalBalance > 0 {
                            Text(WalletDesignSystem.formatTokenAmount(token.totalBalance, decimals: token.decimals) + " " + token.symbol)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    
                    // Selection indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? DesignTokens.Colors.Brand.primary : .white.opacity(0.2))
                        .font(.system(size: 22))
                }
                .padding(.horizontal, DesignTokens.Spacing.regular)
                .padding(.vertical, DesignTokens.Spacing.regular)
                
                // Chain breakdown (if multiple chains)
                if token.chainBalances.count > 1 && isExpanded {
                    VStack(spacing: 0) {
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        ForEach(token.chainBalances.sorted(by: { $0.balanceUSD > $1.balanceUSD }), id: \.chainId) { chainBalance in
                            TokenChainBalanceRow(chainBalance: chainBalance)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium, style: .continuous)
                    .fill(Material.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isSelected ? 0.15 : 0.05),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium, style: .continuous)
                    .strokeBorder(
                        isSelected ? DesignTokens.Colors.Brand.primary.opacity(0.5) : Color.white.opacity(0.1),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .simultaneousGesture(
            token.chainBalances.count > 1 ? TapGesture().onEnded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } : nil
        )
    }
}

struct TokenChainBalanceRow: View {
    let chainBalance: ChainBalance
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.regular) {
            // Chain icon placeholder
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(chainBalance.chainName.prefix(1)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                )
            
            Text(chainBalance.chainName)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(WalletDesignSystem.formatCurrency(chainBalance.balanceUSD))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                
                Text(WalletDesignSystem.formatTokenAmount(chainBalance.balance, decimals: 18))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.regular)
        .padding(.vertical, 12)
    }
}

struct TokenIcon: View {
    let symbol: String
    
    private var initials: String {
        let chars = Array(symbol.prefix(2))
        return String(chars).uppercased()
    }
    
    var body: some View {
        let baseHue = Double(abs(symbol.hashValue % 360)) / 360.0
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: baseHue, saturation: 0.5, brightness: 0.7),
                            Color(hue: baseHue, saturation: 0.7, brightness: 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(initials)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    @State var selectedToken: TokenBalance?
    @State var selectedChainId: Int?
    
    return TokenSelectionView(
        selectedToken: $selectedToken,
        selectedChainId: $selectedChainId,
        tokens: []
    )
}
