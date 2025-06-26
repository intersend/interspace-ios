import SwiftUI

struct WalletViewRedesigned: View {
    @StateObject private var viewModel = WalletViewModel()
    @State private var showTransactionHistory = false
    @State private var showSendSheet = false
    @State private var showReceiveSheet = false
    @State private var selectedToken: UnifiedBalance.TokenBalance?
    @State private var showUniversalAddTray = false
    @State private var showAbout = false
    @State private var showSecurity = false
    @State private var showNotifications = false
    @State private var showSettings = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var scrollOffset: CGFloat = 0
    @State private var expandedTokenId: String?
    @State private var refreshControlHeight: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Main Content
                VStack(spacing: 0) {
                    // Balance Section
                    if let balance = viewModel.unifiedBalance {
                        BalanceDisplaySection(
                            balance: balance,
                            onSend: {
                                selectedToken = nil
                                showSendSheet = true
                            },
                            onReceive: {
                                showReceiveSheet = true
                            },
                            onSwap: {
                                // Swap functionality
                            }
                        )
                    } else if viewModel.isLoading {
                        BalanceLoadingSkeleton()
                            .padding(.top, WalletDesign.Spacing.regular)
                    }
                    
                    // Search Bar (appears on scroll)
                    if isSearching {
                        SearchBar(text: $searchText)
                            .padding(.horizontal, WalletDesign.Spacing.regular)
                            .padding(.vertical, WalletDesign.Spacing.tight)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Content Sections
                    if let balance = viewModel.unifiedBalance {
                        // Tokens Section
                        EnhancedTokenSection(
                            tokens: filteredTokens(balance.unifiedBalance.tokens),
                            expandedTokenId: $expandedTokenId,
                            onTokenTap: { token in
                                withAnimation(WalletDesign.Animation.spring) {
                                    if expandedTokenId == token.standardizedTokenId {
                                        expandedTokenId = nil
                                    } else {
                                        expandedTokenId = token.standardizedTokenId
                                    }
                                }
                                HapticManager.impact(.light)
                            },
                            onSendToken: { token in
                                selectedToken = token
                                showSendSheet = true
                            }
                        )
                        
                        // NFT Gallery
                        NFTGallerySection()
                        
                        // Recent Transactions
                        RecentTransactionsSection(
                            onSeeAll: { showTransactionHistory = true }
                        )
                    }
                    
                    // Bottom padding
                    Spacer(minLength: 20)
                }
            }
        }
        .refreshable {
            await viewModel.refreshBalance()
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                StandardToolbarButtons(
                    showUniversalAddTray: $showUniversalAddTray,
                    showAbout: $showAbout,
                    showSecurity: $showSecurity,
                    showNotifications: $showNotifications,
                    initialSection: .wallet
                )
            }
        }
        .sheet(isPresented: $showUniversalAddTray) {
            UniversalAddTray(isPresented: $showUniversalAddTray, initialSection: .wallet)
        }
        .sheet(isPresented: $showTransactionHistory) {
            TransactionHistoryView()
        }
        .sheet(isPresented: $showSendSheet) {
            SendTokenSheet(selectedToken: selectedToken)
        }
        .sheet(isPresented: $showReceiveSheet) {
            ReceiveSheet()
        }
        .sheet(isPresented: $showAbout) {
            ProfileAboutView()
        }
        .sheet(isPresented: $showSecurity) {
            ProfileSecurityView(showDeleteConfirmation: .constant(false))
        }
        .sheet(isPresented: $showNotifications) {
            ProfileNotificationsView()
        }
        .onAppear {
            Task {
                await ServiceInitializer.shared.wallet.initializeSDKsIfNeeded()
                await viewModel.loadBalance()
            }
        }
    }
    
    private func filteredTokens(_ tokens: [UnifiedBalance.TokenBalance]) -> [UnifiedBalance.TokenBalance] {
        if searchText.isEmpty {
            return tokens
        }
        return tokens.filter { token in
            token.name.localizedCaseInsensitiveContains(searchText) ||
            token.symbol.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Balance Display Section
struct BalanceDisplaySection: View {
    let balance: UnifiedBalance
    let onSend: () -> Void
    let onReceive: () -> Void
    let onSwap: () -> Void
    @State private var displayBalance: Double = 0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: WalletDesign.Spacing.regular) {
            // Balance
            VStack(spacing: WalletDesign.Spacing.micro) {
                Text(displayBalance.formatAsBalance())
                    .font(WalletDesign.Typography.balanceDisplay)
                    .foregroundColor(.primary)
                    .onAppear {
                        withAnimation(WalletDesign.Animation.numberTransition) {
                            displayBalance = Double(balance.unifiedBalance.totalUsdValue) ?? 0
                        }
                    }
                
                // Change Indicator
                HStack(spacing: WalletDesign.Spacing.micro) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .medium))
                    Text("+$1,234.56")
                        .font(WalletDesign.Typography.balanceChange)
                    Text("(+2.4%)")
                        .font(WalletDesign.Typography.balanceChange)
                }
                .foregroundColor(WalletDesign.Colors.positiveChange)
            }
            
            // Action Buttons - Apple Style
            HStack(spacing: 12) {
                WalletActionButton(
                    title: "Send",
                    icon: "arrow.up",
                    action: onSend
                )
                
                WalletActionButton(
                    title: "Receive", 
                    icon: "arrow.down",
                    action: onReceive
                )
                
                WalletActionButton(
                    title: "Swap",
                    icon: "arrow.left.arrow.right",
                    action: onSwap
                )
            }
            .padding(.horizontal, WalletDesign.Spacing.regular)
        }
        .padding(.vertical, WalletDesign.Spacing.regular)
        .padding(.top, WalletDesign.Spacing.tight)
    }
}

// MARK: - Wallet Action Button
private struct WalletActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            action()
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color(UIColor.systemBlue))
                    .frame(width: 48, height: 48)
                    .background(Color(UIColor.systemBlue).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: WalletSymbols.search)
                .foregroundColor(Color(UIColor.secondaryLabel))
            
            TextField("Search tokens", text: $text)
                .focused($isFocused)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
        }
        .padding(.horizontal, WalletDesign.Spacing.tight)
        .frame(height: WalletDesign.Sizing.searchBarHeight)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(Capsule())
    }
}

// MARK: - Enhanced Token Section
struct EnhancedTokenSection: View {
    let tokens: [UnifiedBalance.TokenBalance]
    @Binding var expandedTokenId: String?
    let onTokenTap: (UnifiedBalance.TokenBalance) -> Void
    let onSendToken: (UnifiedBalance.TokenBalance) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tokens")
                .sectionHeaderStyle()
            
            LazyVStack(spacing: 0) {
                ForEach(tokens, id: \.standardizedTokenId) { token in
                    EnhancedTokenCell(
                        token: token,
                        isExpanded: expandedTokenId == token.standardizedTokenId,
                        onTap: { onTokenTap(token) },
                        onSend: { onSendToken(token) }
                    )
                }
            }
            .walletCard()
            .padding(.horizontal, WalletDesign.Spacing.regular)
        }
    }
}

// MARK: - Enhanced Token Cell
struct EnhancedTokenCell: View {
    let token: UnifiedBalance.TokenBalance
    let isExpanded: Bool
    let onTap: () -> Void
    let onSend: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: WalletDesign.Spacing.regular) {
                    // Token Icon
                    ZStack {
                        Circle()
                            .fill(WalletDesign.Colors.tokenIcon)
                            .frame(width: WalletDesign.Sizing.tokenIcon, height: WalletDesign.Sizing.tokenIcon)
                        
                        Text(token.symbol.prefix(2).uppercased())
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    // Token Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(token.symbol)
                            .font(WalletDesign.Typography.tokenName)
                            .foregroundColor(.primary)
                        
                        Text(token.name)
                            .font(WalletDesign.Typography.chainLabel)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Balance
                    VStack(alignment: .trailing, spacing: 2) {
                        Text((Double(token.totalUsdValue) ?? 0).formatAsBalance())
                            .font(WalletDesign.Typography.tokenBalance)
                            .foregroundColor(.primary)
                        
                        Text("\(formatTokenAmount(token.totalAmount, decimals: token.decimals)) \(token.symbol)")
                            .font(WalletDesign.Typography.chainLabel)
                            .foregroundColor(.secondary)
                    }
                    
                    // Expand Icon
                    Image(systemName: isExpanded ? WalletSymbols.collapse : WalletSymbols.expand)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .tokenCellStyle()
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
            
            // Expanded Chain Details
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.leading, WalletDesign.Sizing.tokenIcon + WalletDesign.Spacing.regular)
                    
                    ForEach(token.balancesPerChain, id: \.chainId) { chainBalance in
                        HStack {
                            Image(systemName: WalletSymbols.chainLink)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(width: WalletDesign.Sizing.tokenIcon)
                            
                            Text(chainBalance.chainName)
                                .font(WalletDesign.Typography.chainLabel)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(formatTokenAmount(chainBalance.amount, decimals: token.decimals))
                                .font(WalletDesign.Typography.chainLabel)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, WalletDesign.Spacing.regular)
                        .padding(.vertical, WalletDesign.Spacing.tight)
                    }
                    
                    // Action Buttons
                    HStack(spacing: WalletDesign.Spacing.tight) {
                        Button(action: onSend) {
                            HStack {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Send")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(WalletDesign.Colors.actionPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Swap")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(WalletDesign.Colors.actionPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(WalletDesign.Colors.actionPrimary, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, WalletDesign.Spacing.regular)
                    .padding(.bottom, WalletDesign.Spacing.regular)
                    .padding(.top, WalletDesign.Spacing.tight)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            if token.standardizedTokenId != token.standardizedTokenId {
                Divider()
                    .padding(.leading, WalletDesign.Sizing.tokenIcon + WalletDesign.Spacing.regular)
            }
        }
        .animation(WalletDesign.Animation.spring, value: isExpanded)
    }
    
    private func formatTokenAmount(_ amount: String, decimals: Int) -> String {
        guard let doubleValue = Double(amount) else { return "0" }
        let adjustedValue = doubleValue / pow(10, Double(decimals))
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        if adjustedValue < 0.01 {
            formatter.maximumFractionDigits = 6
        } else if adjustedValue < 1 {
            formatter.maximumFractionDigits = 4
        } else {
            formatter.maximumFractionDigits = 2
        }
        
        return formatter.string(from: NSNumber(value: adjustedValue)) ?? "0"
    }
}

// MARK: - NFT Gallery Section
struct NFTGallerySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NFTs")
                    .sectionHeaderStyle()
                
                Spacer()
                
                Button("See All") {
                    // Navigate to full NFT gallery
                }
                .font(WalletDesign.Typography.tokenValue)
                .foregroundColor(WalletDesign.Colors.actionPrimary)
                .padding(.trailing, WalletDesign.Spacing.regular)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WalletDesign.Spacing.regular) {
                    ForEach(0..<5, id: \.self) { _ in
                        NFTCard()
                    }
                }
                .padding(.horizontal, WalletDesign.Spacing.regular)
            }
        }
    }
}

// MARK: - NFT Card
struct NFTCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: WalletDesign.Spacing.tight) {
            // NFT Image Placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [Color(UIColor.systemGray5), Color(UIColor.systemGray4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: WalletDesign.Sizing.nftThumbnail, height: WalletDesign.Sizing.nftThumbnail / WalletDesign.Sizing.nftAspectRatio)
                .overlay(
                    Image(systemName: WalletSymbols.nft)
                        .font(.system(size: 30))
                        .foregroundColor(Color(UIColor.systemGray3))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("NFT Name")
                    .font(WalletDesign.Typography.tokenName)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("Collection")
                    .font(WalletDesign.Typography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: WalletDesign.Sizing.nftThumbnail)
        }
    }
}

// MARK: - Recent Transactions Section
struct RecentTransactionsSection: View {
    let onSeeAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent Transactions")
                    .sectionHeaderStyle()
                
                Spacer()
                
                Button("See All", action: onSeeAll)
                    .font(WalletDesign.Typography.tokenValue)
                    .foregroundColor(WalletDesign.Colors.actionPrimary)
                    .padding(.trailing, WalletDesign.Spacing.regular)
            }
            
            LazyVStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    TransactionCell(isLast: index == 2)
                }
            }
            .walletCard()
            .padding(.horizontal, WalletDesign.Spacing.regular)
        }
    }
}

// MARK: - Transaction Cell
struct TransactionCell: View {
    let isLast: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: WalletDesign.Spacing.regular) {
                // Transaction Icon
                ZStack {
                    Circle()
                        .fill(WalletDesign.Colors.positiveChange.opacity(0.1))
                        .frame(width: WalletDesign.Sizing.transactionIcon, height: WalletDesign.Sizing.transactionIcon)
                    
                    Image(systemName: WalletSymbols.receive)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(WalletDesign.Colors.positiveChange)
                }
                
                // Transaction Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Received ETH")
                        .font(WalletDesign.Typography.tokenName)
                        .foregroundColor(.primary)
                    
                    Text("2 hours ago")
                        .font(WalletDesign.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Amount
                Text("+0.05 ETH")
                    .font(WalletDesign.Typography.transactionAmount)
                    .foregroundColor(WalletDesign.Colors.positiveChange)
            }
            .padding(.horizontal, WalletDesign.Spacing.regular)
            .padding(.vertical, WalletDesign.Spacing.regular)
            
            if !isLast {
                Divider()
                    .padding(.leading, WalletDesign.Sizing.transactionIcon + WalletDesign.Spacing.regular)
            }
        }
    }
}


// MARK: - Loading Skeletons
struct BalanceLoadingSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: WalletDesign.Spacing.tight) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.systemGray5))
                .frame(width: 200, height: 56)
                .shimmerEffect(isLoading: true)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(UIColor.systemGray6))
                .frame(width: 120, height: 20)
                .shimmerEffect(isLoading: true)
        }
        .padding(.vertical, WalletDesign.Spacing.section)
    }
}

// MARK: - Refresh Control
struct RefreshControl: View {
    let height: CGFloat
    
    var body: some View {
        ZStack {
            if height > 60 {
                ProgressView()
                    .scaleEffect(min(1, height / 100))
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Receive Sheet
struct ReceiveSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Receive placeholder")
            }
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}