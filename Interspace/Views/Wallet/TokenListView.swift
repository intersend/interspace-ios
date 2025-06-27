import SwiftUI
import Combine

struct TokenListView: View {
    let tokens: [UnifiedBalance.TokenBalance]
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var expandedTokenIds: Set<String> = []
    @State private var sortOption: TokenSortOption = .value
    @State private var showSortMenu = false
    @FocusState private var searchFieldFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    private var filteredAndSortedTokens: [UnifiedBalance.TokenBalance] {
        let filtered = searchText.isEmpty ? tokens : tokens.filter { token in
            token.name.localizedCaseInsensitiveContains(searchText) ||
            token.symbol.localizedCaseInsensitiveContains(searchText)
        }
        
        return filtered.sorted { lhs, rhs in
            switch sortOption {
            case .value:
                return (Double(lhs.totalUsdValue) ?? 0) > (Double(rhs.totalUsdValue) ?? 0)
            case .name:
                return lhs.name < rhs.name
            case .change:
                // Mock change data for now
                return true
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Search
            VStack(spacing: WalletDesign.Spacing.tight) {
                // Section Title and Sort
                HStack {
                    Text("Tokens")
                        .font(WalletDesign.Typography.sectionHeader)
                        .foregroundColor(.primary)
                    
                    Text("\(filteredAndSortedTokens.count)")
                        .font(WalletDesign.Typography.chainLabel)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    // Sort Button
                    Button(action: { showSortMenu.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: WalletSymbols.filter)
                                .font(.system(size: 14, weight: .medium))
                            Text(sortOption.displayName)
                                .font(WalletDesign.Typography.chainLabel)
                        }
                        .foregroundColor(WalletDesign.Colors.actionPrimary)
                    }
                    .confirmationDialog("Sort by", isPresented: $showSortMenu) {
                        ForEach(TokenSortOption.allCases) { option in
                            Button(option.displayName) {
                                withAnimation(WalletDesign.Animation.spring) {
                                    sortOption = option
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, WalletDesign.Spacing.regular)
                .padding(.top, WalletDesign.Spacing.section)
                .padding(.bottom, WalletDesign.Spacing.tight)
                
                // Search Bar
                if isSearching {
                    SearchBarView(
                        text: $searchText,
                        placeholder: "Search tokens",
                        onCancel: {
                            withAnimation(WalletDesign.Animation.spring) {
                                isSearching = false
                                searchText = ""
                                searchFieldFocused = false
                            }
                        }
                    )
                    .focused($searchFieldFocused)
                    .padding(.horizontal, WalletDesign.Spacing.regular)
                    .padding(.bottom, WalletDesign.Spacing.tight)
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
                }
            }
            
            // Token List
            if filteredAndSortedTokens.isEmpty {
                EmptySearchState(searchText: searchText)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredAndSortedTokens.enumerated()), id: \.element.standardizedTokenId) { index, token in
                            EnhancedTokenCell(
                                token: token,
                                isExpanded: expandedTokenIds.contains(token.standardizedTokenId),
                                isFirst: index == 0,
                                isLast: index == filteredAndSortedTokens.count - 1,
                                onTap: {
                                    toggleTokenExpansion(token.standardizedTokenId)
                                }
                            )
                        }
                    }
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, WalletDesign.Spacing.regular)
                    .padding(.bottom, WalletDesign.Spacing.regular)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation(WalletDesign.Animation.spring) {
                        isSearching.toggle()
                        if isSearching {
                            searchFieldFocused = true
                        }
                    }
                }) {
                    Image(systemName: WalletSymbols.search)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    private func toggleTokenExpansion(_ tokenId: String) {
        withAnimation(WalletDesign.Animation.spring) {
            if expandedTokenIds.contains(tokenId) {
                expandedTokenIds.remove(tokenId)
            } else {
                expandedTokenIds.insert(tokenId)
            }
        }
        HapticManager.impact(.light)
    }
}

// MARK: - Enhanced Token Cell
struct EnhancedTokenCell: View {
    let token: UnifiedBalance.TokenBalance
    let isExpanded: Bool
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var showActions = false
    
    // Mock data for demonstration
    private let change24h = Double.random(in: -10...20)
    private var changeColor: Color {
        change24h >= 0 ? WalletDesign.Colors.positiveChange : WalletDesign.Colors.negativeChange
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Cell Content
            Button(action: onTap) {
                HStack(spacing: WalletDesign.Spacing.regular) {
                    // Token Icon
                    TokenIcon(symbol: token.symbol)
                    
                    // Token Info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(token.symbol)
                                .font(WalletDesign.Typography.tokenName)
                                .foregroundColor(.primary)
                            
                            if token.balancesPerChain.count > 1 {
                                Text("\(token.balancesPerChain.count)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color(UIColor.tertiarySystemBackground))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Text(token.name)
                            .font(WalletDesign.Typography.chainLabel)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Balance and Change
                    VStack(alignment: .trailing, spacing: 4) {
                        Text((Double(token.totalUsdValue) ?? 0).formatAsBalance())
                            .font(WalletDesign.Typography.tokenBalance)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Text("\(change24h >= 0 ? "+" : "")\(change24h, specifier: "%.1f")%")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(changeColor)
                            
                            Image(systemName: change24h >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(changeColor)
                        }
                    }
                    
                    // Expand Indicator
                    Image(systemName: WalletSymbols.expand)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, WalletDesign.Spacing.regular)
                .padding(.vertical, WalletDesign.Spacing.regular)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .background(isPressed ? Color(UIColor.systemGray5) : Color.clear)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(.easeOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.1)) {
                            isPressed = false
                        }
                    }
            )
            
            // Expanded Content
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.leading, WalletDesign.Sizing.tokenIcon + WalletDesign.Spacing.regular * 2)
                    
                    // Chain Breakdown
                    VStack(spacing: 0) {
                        ForEach(Array(token.balancesPerChain.enumerated()), id: \.element.chainId) { index, chainBalance in
                            ChainBalanceRow(
                                chainBalance: chainBalance,
                                token: token,
                                isLast: index == token.balancesPerChain.count - 1
                            )
                        }
                    }
                    .padding(.vertical, WalletDesign.Spacing.tight)
                    
                    // Quick Actions
                    HStack(spacing: WalletDesign.Spacing.tight) {
                        TokenActionButton(title: "Send", icon: "arrow.up", action: {})
                        TokenActionButton(title: "Receive", icon: "arrow.down", action: {})
                        TokenActionButton(title: "Swap", icon: "arrow.left.arrow.right", action: {})
                        TokenActionButton(title: "More", icon: "ellipsis", action: { showActions = true })
                    }
                    .padding(.horizontal, WalletDesign.Spacing.regular)
                    .padding(.bottom, WalletDesign.Spacing.regular)
                }
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }
            
            // Separator
            if !isLast && !isExpanded {
                Divider()
                    .padding(.leading, WalletDesign.Sizing.tokenIcon + WalletDesign.Spacing.regular * 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isFirst || isLast ? 16 : 0))
        .actionSheet(isPresented: $showActions) {
            ActionSheet(
                title: Text("\(token.symbol) Actions"),
                buttons: [
                    .default(Text("View on Explorer")) {},
                    .default(Text("Hide Token")) {},
                    .default(Text("Price Alert")) {},
                    .cancel()
                ]
            )
        }
    }
}

// MARK: - Token Icon
struct TokenIcon: View {
    let symbol: String
    @State private var imageLoaded = false
    
    var body: some View {
        ZStack {
            if imageLoaded {
                // Placeholder for actual token image
                Circle()
                    .fill(
                        LinearGradient(
                            colors: generateGradientColors(from: symbol),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                Circle()
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .overlay(
                        Text(symbol.prefix(2).uppercased())
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    )
            }
        }
        .frame(width: WalletDesign.Sizing.tokenIcon, height: WalletDesign.Sizing.tokenIcon)
    }
    
    private func generateGradientColors(from string: String) -> [Color] {
        let hash = string.hashValue
        let hue1 = Double(abs(hash % 360)) / 360.0
        let hue2 = (hue1 + 0.1).truncatingRemainder(dividingBy: 1.0)
        
        return [
            Color(hue: hue1, saturation: 0.5, brightness: 0.9),
            Color(hue: hue2, saturation: 0.6, brightness: 0.8)
        ]
    }
}

// MARK: - Chain Balance Row
struct ChainBalanceRow: View {
    let chainBalance: UnifiedBalance.ChainBalance
    let token: UnifiedBalance.TokenBalance
    let isLast: Bool
    
    var body: some View {
        HStack(spacing: WalletDesign.Spacing.regular) {
            // Chain Icon
            ZStack {
                Circle()
                    .fill(Color(UIColor.quaternarySystemFill))
                    .frame(width: 28, height: 28)
                
                Image(systemName: WalletSymbols.chainLink)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.leading, WalletDesign.Spacing.regular)
            
            // Chain Name
            Text(chainBalance.chainName)
                .font(WalletDesign.Typography.chainLabel)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Balance
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTokenAmount(chainBalance.amount, decimals: token.decimals))
                    .font(WalletDesign.Typography.chainLabel)
                    .foregroundColor(.primary)
                
                if chainBalance.isNative {
                    Text("Native")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.trailing, WalletDesign.Spacing.regular)
        }
        .padding(.vertical, WalletDesign.Spacing.tight)
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .padding(.leading, 28 + WalletDesign.Spacing.regular * 2)
            }
        }
    }
    
    private func formatTokenAmount(_ amount: String, decimals: Int) -> String {
        guard let doubleValue = Double(amount) else { return "0" }
        let adjustedValue = doubleValue / pow(10, Double(decimals))
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = adjustedValue < 1 ? 6 : 4
        
        return formatter.string(from: NSNumber(value: adjustedValue)) ?? "0"
    }
}

// MARK: - Token Action Button
struct TokenActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Search Bar View
struct SearchBarView: View {
    @Binding var text: String
    let placeholder: String
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: WalletDesign.Spacing.tight) {
            HStack {
                Image(systemName: WalletSymbols.search)
                    .foregroundColor(.secondary)
                    .font(.system(size: 15, weight: .medium))
                
                TextField(placeholder, text: $text)
                    .focused($isFocused)
                    .submitLabel(.search)
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        HapticManager.impact(.light)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, WalletDesign.Spacing.tight)
            .padding(.vertical, 8)
            .background(Color(UIColor.tertiarySystemBackground))
            .clipShape(Capsule())
            
            Button("Cancel", action: onCancel)
                .font(WalletDesign.Typography.tokenValue)
                .foregroundColor(WalletDesign.Colors.actionPrimary)
        }
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Empty Search State
struct EmptySearchState: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: WalletDesign.Spacing.regular) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.secondary)
            
            Text("No tokens found")
                .font(WalletDesign.Typography.tokenName)
                .foregroundColor(.primary)
            
            if !searchText.isEmpty {
                Text("No results for \"\(searchText)\"")
                    .font(WalletDesign.Typography.chainLabel)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, WalletDesign.Spacing.hero)
    }
}

// MARK: - Token Sort Options
enum TokenSortOption: String, CaseIterable, Identifiable {
    case value = "Value"
    case name = "Name"
    case change = "24h Change"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
}