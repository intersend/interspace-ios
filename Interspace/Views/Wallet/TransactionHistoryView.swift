import SwiftUI

struct TransactionHistoryView: View {
    @StateObject private var viewModel = TransactionHistoryViewModel()
    @State private var selectedFilter: TransactionFilter = .all
    @State private var selectedTransaction: Transaction?
    @State private var searchText = ""
    @State private var showFilters = false
    @State private var dateRange: DateRange = .lastMonth
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                // Content
                VStack(spacing: 0) {
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: WalletDesign.Spacing.tight) {
                            FilterPill(
                                title: "All",
                                isSelected: selectedFilter == .all,
                                count: viewModel.allTransactionsCount
                            ) {
                                selectedFilter = .all
                            }
                            
                            FilterPill(
                                title: "Sent",
                                isSelected: selectedFilter == .sent,
                                count: viewModel.sentTransactionsCount
                            ) {
                                selectedFilter = .sent
                            }
                            
                            FilterPill(
                                title: "Received",
                                isSelected: selectedFilter == .received,
                                count: viewModel.receivedTransactionsCount
                            ) {
                                selectedFilter = .received
                            }
                            
                            FilterPill(
                                title: "Swapped",
                                isSelected: selectedFilter == .swapped,
                                count: viewModel.swappedTransactionsCount
                            ) {
                                selectedFilter = .swapped
                            }
                            
                            FilterPill(
                                title: "Failed",
                                isSelected: selectedFilter == .failed,
                                count: viewModel.failedTransactionsCount
                            ) {
                                selectedFilter = .failed
                            }
                        }
                        .padding(.horizontal, WalletDesign.Spacing.regular)
                    }
                    .padding(.vertical, WalletDesign.Spacing.tight)
                    
                    // Transaction List
                    if viewModel.isLoading && viewModel.groupedTransactions.isEmpty {
                        TransactionLoadingSkeleton()
                    } else if viewModel.groupedTransactions.isEmpty {
                        EmptyTransactionState(filter: selectedFilter)
                    } else {
                        TransactionList(
                            groupedTransactions: filteredTransactions,
                            onTransactionTap: { transaction in
                                selectedTransaction = transaction
                                HapticManager.impact(.light)
                            },
                            onLoadMore: {
                                Task {
                                    await viewModel.loadMoreTransactions()
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(WalletDesign.Typography.tokenValue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: WalletDesign.Spacing.tight) {
                        Button(action: { showFilters = true }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 17, weight: .medium))
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .medium))
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction)
            }
            .sheet(isPresented: $showFilters) {
                TransactionFilterSheet(
                    dateRange: $dateRange,
                    onApply: {
                        Task {
                            await viewModel.applyFilters(dateRange: dateRange)
                        }
                    }
                )
            }
            .task {
                await viewModel.loadTransactions()
            }
        }
    }
    
    private var filteredTransactions: [TransactionGroup] {
        viewModel.groupedTransactions.compactMap { group in
            let filtered = group.transactions.filter { transaction in
                // Filter by type
                let matchesFilter = selectedFilter == .all || transaction.matchesFilter(selectedFilter)
                
                // Filter by search
                let matchesSearch = searchText.isEmpty || 
                    transaction.description.localizedCaseInsensitiveContains(searchText) ||
                    transaction.tokenSymbol.localizedCaseInsensitiveContains(searchText)
                
                return matchesFilter && matchesSearch
            }
            
            return filtered.isEmpty ? nil : TransactionGroup(date: group.date, transactions: filtered)
        }
    }
}

// MARK: - Transaction List
struct TransactionList: View {
    let groupedTransactions: [TransactionGroup]
    let onTransactionTap: (Transaction) -> Void
    let onLoadMore: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(groupedTransactions) { group in
                    Section {
                        ForEach(Array(group.transactions.enumerated()), id: \.element.id) { index, transaction in
                            TransactionRow(
                                transaction: transaction,
                                isLast: index == group.transactions.count - 1,
                                onTap: { onTransactionTap(transaction) }
                            )
                        }
                    } header: {
                        TransactionDateHeader(date: group.date)
                    }
                }
                
                // Load More
                if !groupedTransactions.isEmpty {
                    LoadMoreButton(action: onLoadMore)
                        .padding(.vertical, WalletDesign.Spacing.regular)
                }
            }
        }
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: Transaction
    let isLast: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: WalletDesign.Spacing.regular) {
                // Transaction Icon
                TransactionIcon(type: transaction.type, status: transaction.status)
                
                // Transaction Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.description)
                        .font(WalletDesign.Typography.tokenName)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(transaction.formattedTime)
                            .font(WalletDesign.Typography.caption)
                            .foregroundColor(.secondary)
                        
                        if transaction.status == .pending {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                                Text("Pending")
                                    .font(WalletDesign.Typography.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Amount
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(transaction.formattedAmount)
                            .font(WalletDesign.Typography.transactionAmount)
                            .foregroundColor(transaction.amountColor)
                        
                        Text(transaction.tokenSymbol)
                            .font(WalletDesign.Typography.chainLabel)
                            .foregroundColor(transaction.amountColor)
                    }
                    
                    if let usdValue = transaction.usdValue {
                        Text(usdValue)
                            .font(WalletDesign.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, WalletDesign.Spacing.regular)
            .padding(.vertical, WalletDesign.Spacing.regular)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(isPressed ? Color(UIColor.systemGray6) : Color.clear)
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
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .padding(.leading, WalletDesign.Sizing.transactionIcon + WalletDesign.Spacing.regular * 2)
            }
        }
    }
}

// MARK: - Transaction Icon
struct TransactionIcon: View {
    let type: TransactionType
    let status: TransactionStatus
    
    private var icon: String {
        switch type {
        case .sent: return WalletSymbols.send
        case .received: return WalletSymbols.receive
        case .swap: return WalletSymbols.swap
        case .contractInteraction: return "doc.text.fill"
        case .approval: return "checkmark.shield.fill"
        }
    }
    
    private var iconColor: Color {
        if status == .failed {
            return WalletDesign.Colors.negativeChange
        }
        
        switch type {
        case .sent: return WalletDesign.Colors.actionPrimary
        case .received: return WalletDesign.Colors.positiveChange
        case .swap: return Color.orange
        case .contractInteraction: return Color.purple
        case .approval: return Color.indigo
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.1))
                .frame(width: WalletDesign.Sizing.transactionIcon, height: WalletDesign.Sizing.transactionIcon)
            
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(iconColor)
            
            if status == .failed {
                Circle()
                    .fill(Color(UIColor.systemBackground))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(WalletDesign.Colors.negativeChange)
                    )
                    .offset(x: 10, y: 10)
            }
        }
    }
}

// MARK: - Transaction Date Header
struct TransactionDateHeader: View {
    let date: Date
    
    private var formattedDate: String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        HStack {
            Text(formattedDate)
                .font(WalletDesign.Typography.tokenName)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, WalletDesign.Spacing.regular)
        .padding(.vertical, WalletDesign.Spacing.tight)
        .background(
            Color(UIColor.systemBackground)
                .opacity(0.95)
        )
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let count: Int?
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(WalletDesign.Animation.spring) {
                action()
            }
            HapticManager.selection()
        }) {
            HStack(spacing: 4) {
                Text(title)
                    .font(WalletDesign.Typography.tokenValue)
                
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(WalletDesign.Typography.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.2) : Color(UIColor.tertiarySystemBackground))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, WalletDesign.Spacing.regular)
            .padding(.vertical, WalletDesign.Spacing.tight)
            .background(
                Capsule()
                    .fill(isSelected ? WalletDesign.Colors.actionPrimary : Color(UIColor.secondarySystemBackground))
            )
        }
    }
}

// MARK: - Empty State
struct EmptyTransactionState: View {
    let filter: TransactionFilter
    
    private var message: String {
        switch filter {
        case .all: return "No transactions yet"
        case .sent: return "No sent transactions"
        case .received: return "No received transactions"
        case .swapped: return "No swap transactions"
        case .failed: return "No failed transactions"
        }
    }
    
    var body: some View {
        VStack(spacing: WalletDesign.Spacing.regular) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(WalletDesign.Typography.tokenName)
                .foregroundColor(.primary)
            
            Text("Your transaction history will appear here")
                .font(WalletDesign.Typography.chainLabel)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, WalletDesign.Spacing.hero)
    }
}

// MARK: - Loading Skeleton
struct TransactionLoadingSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<10) { _ in
                HStack(spacing: WalletDesign.Spacing.regular) {
                    Circle()
                        .fill(Color(UIColor.systemGray5))
                        .frame(width: WalletDesign.Sizing.transactionIcon, height: WalletDesign.Sizing.transactionIcon)
                        .shimmerEffect(isLoading: true)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 120, height: 16)
                            .shimmerEffect(isLoading: true)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray6))
                            .frame(width: 80, height: 12)
                            .shimmerEffect(isLoading: true)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 80, height: 16)
                            .shimmerEffect(isLoading: true)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray6))
                            .frame(width: 60, height: 12)
                            .shimmerEffect(isLoading: true)
                    }
                }
                .padding(.horizontal, WalletDesign.Spacing.regular)
                .padding(.vertical, WalletDesign.Spacing.regular)
            }
        }
    }
}

// MARK: - Load More Button
struct LoadMoreButton: View {
    let action: () -> Void
    @State private var isLoading = false
    
    var body: some View {
        Button(action: {
            isLoading = true
            action()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isLoading = false
            }
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Text("Load More")
                        .font(WalletDesign.Typography.tokenValue)
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundColor(WalletDesign.Colors.actionPrimary)
            .padding(.horizontal, WalletDesign.Spacing.regular)
            .padding(.vertical, WalletDesign.Spacing.tight)
            .background(
                Capsule()
                    .stroke(WalletDesign.Colors.actionPrimary, lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }
}

// MARK: - Transaction Detail View
struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: WalletDesign.Spacing.section) {
                    // Transaction Header
                    VStack(spacing: WalletDesign.Spacing.regular) {
                        TransactionIcon(type: transaction.type, status: transaction.status)
                            .scaleEffect(1.5)
                            .padding(.bottom, WalletDesign.Spacing.tight)
                        
                        Text(transaction.description)
                            .font(WalletDesign.Typography.sectionHeader)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Text(transaction.formattedAmount)
                                .font(WalletDesign.Typography.balanceChange)
                                .foregroundColor(transaction.amountColor)
                            
                            Text(transaction.tokenSymbol)
                                .font(WalletDesign.Typography.balanceChange)
                                .foregroundColor(transaction.amountColor)
                        }
                        
                        if let usdValue = transaction.usdValue {
                            Text(usdValue)
                                .font(WalletDesign.Typography.tokenValue)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Transaction Details
                    VStack(spacing: 0) {
                        DetailRow(label: "Status", value: transaction.status.displayName, valueColor: transaction.status.color)
                        DetailRow(label: "Date", value: transaction.formattedDate)
                        DetailRow(label: "Time", value: transaction.formattedTime)
                        DetailRow(label: "Network", value: transaction.chainName)
                        DetailRow(label: "Network Fee", value: transaction.formattedGasFee ?? "—")
                        
                        if let hash = transaction.hash {
                            DetailRow(label: "Transaction Hash", value: hash.truncatedHash, isMonospace: true, action: {
                                // Copy to clipboard
                                UIPasteboard.general.string = hash
                                HapticManager.notification(.success)
                            })
                        }
                        
                        if let from = transaction.from {
                            DetailRow(label: "From", value: from.truncatedAddress, isMonospace: true, action: {
                                UIPasteboard.general.string = from
                                HapticManager.notification(.success)
                            })
                        }
                        
                        if let to = transaction.to {
                            DetailRow(label: "To", value: to.truncatedAddress, isMonospace: true, action: {
                                UIPasteboard.general.string = to
                                HapticManager.notification(.success)
                            })
                        }
                    }
                    .walletCard()
                    .padding(.horizontal, WalletDesign.Spacing.regular)
                    
                    // Actions
                    VStack(spacing: WalletDesign.Spacing.tight) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "safari")
                                Text("View on Explorer")
                            }
                            .font(WalletDesign.Typography.tokenValue)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, WalletDesign.Spacing.regular)
                            .background(WalletDesign.Colors.actionPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(WalletDesign.Typography.tokenValue)
                            .foregroundColor(WalletDesign.Colors.actionPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, WalletDesign.Spacing.regular)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(WalletDesign.Colors.actionPrimary, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, WalletDesign.Spacing.regular)
                }
                .padding(.vertical, WalletDesign.Spacing.regular)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    var isMonospace = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(label)
                .font(WalletDesign.Typography.tokenValue)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if let action = action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(value)
                            .font(isMonospace ? .system(size: 15, design: .monospaced) : WalletDesign.Typography.tokenValue)
                            .foregroundColor(valueColor)
                        
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text(value)
                    .font(isMonospace ? .system(size: 15, design: .monospaced) : WalletDesign.Typography.tokenValue)
                    .foregroundColor(valueColor)
            }
        }
        .padding(.horizontal, WalletDesign.Spacing.regular)
        .padding(.vertical, WalletDesign.Spacing.regular)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

// MARK: - Filter Sheet
struct TransactionFilterSheet: View {
    @Binding var dateRange: DateRange
    let onApply: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: WalletDesign.Spacing.section) {
                // Date Range
                VStack(alignment: .leading, spacing: WalletDesign.Spacing.regular) {
                    Text("Date Range")
                        .font(WalletDesign.Typography.tokenName)
                        .foregroundColor(.primary)
                    
                    ForEach(DateRange.allCases) { range in
                        DateRangeOption(
                            range: range,
                            isSelected: dateRange == range,
                            action: { dateRange = range }
                        )
                    }
                }
                .padding(.horizontal, WalletDesign.Spacing.regular)
                
                Spacer()
                
                // Apply Button
                Button(action: {
                    onApply()
                    dismiss()
                }) {
                    Text("Apply Filters")
                        .font(WalletDesign.Typography.tokenName)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, WalletDesign.Spacing.regular)
                        .background(WalletDesign.Colors.actionPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, WalletDesign.Spacing.regular)
            }
            .padding(.vertical, WalletDesign.Spacing.regular)
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Filter Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Date Range Option
struct DateRangeOption: View {
    let range: DateRange
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(range.displayName)
                    .font(WalletDesign.Typography.tokenValue)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(WalletDesign.Colors.actionPrimary)
                }
            }
            .padding(.vertical, WalletDesign.Spacing.tight)
        }
    }
}

// MARK: - Models
struct Transaction: Identifiable {
    let id = UUID().uuidString
    let type: TransactionType
    let status: TransactionStatus
    let description: String
    let amount: Double
    let tokenSymbol: String
    let usdValue: String?
    let date: Date
    let chainId: Int
    let chainName: String
    let hash: String?
    let from: String?
    let to: String?
    let gasFee: Double?
    
    var formattedAmount: String {
        let sign = type == .received ? "+" : "-"
        return "\(sign)\(String(format: "%.4f", abs(amount)))"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    var formattedGasFee: String? {
        guard let fee = gasFee else { return nil }
        return "$\(String(format: "%.2f", fee))"
    }
    
    var amountColor: Color {
        if status == .failed {
            return .secondary
        }
        
        switch type {
        case .received: return WalletDesign.Colors.positiveChange
        case .sent, .approval: return .primary
        case .swap, .contractInteraction: return .primary
        }
    }
    
    func matchesFilter(_ filter: TransactionFilter) -> Bool {
        switch filter {
        case .all: return true
        case .sent: return type == .sent
        case .received: return type == .received
        case .swapped: return type == .swap
        case .failed: return status == .failed
        }
    }
}

struct TransactionGroup: Identifiable {
    let id = UUID().uuidString
    let date: Date
    let transactions: [Transaction]
}

enum TransactionType {
    case sent, received, swap, contractInteraction, approval
}

enum TransactionStatus {
    case confirmed, pending, failed
    
    var displayName: String {
        switch self {
        case .confirmed: return "Confirmed"
        case .pending: return "Pending"
        case .failed: return "Failed"
        }
    }
    
    var color: Color {
        switch self {
        case .confirmed: return .green
        case .pending: return .orange
        case .failed: return .red
        }
    }
}

enum TransactionFilter: CaseIterable {
    case all, sent, received, swapped, failed
}

enum DateRange: String, CaseIterable, Identifiable {
    case today = "Today"
    case lastWeek = "Last 7 Days"
    case lastMonth = "Last 30 Days"
    case lastThreeMonths = "Last 3 Months"
    case lastYear = "Last Year"
    case allTime = "All Time"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
}

// MARK: - View Model
class TransactionHistoryViewModel: ObservableObject {
    @Published var groupedTransactions: [TransactionGroup] = []
    @Published var isLoading = false
    @Published var hasMoreData = true
    
    var allTransactionsCount: Int { 42 }
    var sentTransactionsCount: Int { 15 }
    var receivedTransactionsCount: Int { 20 }
    var swappedTransactionsCount: Int { 5 }
    var failedTransactionsCount: Int { 2 }
    
    @MainActor
    func loadTransactions() async {
        isLoading = true
        
        // Simulate API delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Mock data
        let mockTransactions = generateMockTransactions()
        groupedTransactions = groupTransactionsByDate(mockTransactions)
        
        isLoading = false
    }
    
    @MainActor
    func loadMoreTransactions() async {
        // Simulate loading more
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let moreTransactions = generateMockTransactions(offset: groupedTransactions.count * 10)
        let newGroups = groupTransactionsByDate(moreTransactions)
        groupedTransactions.append(contentsOf: newGroups)
    }
    
    @MainActor
    func applyFilters(dateRange: DateRange) async {
        await loadTransactions()
    }
    
    private func generateMockTransactions(offset: Int = 0) -> [Transaction] {
        let types: [TransactionType] = [.sent, .received, .swap, .contractInteraction, .approval]
        let statuses: [TransactionStatus] = [.confirmed, .confirmed, .confirmed, .pending, .failed]
        let tokens = ["ETH", "USDC", "WBTC", "DAI", "LINK"]
        
        return (0..<20).map { index in
            let type = types.randomElement()!
            let status = statuses.randomElement()!
            let token = tokens.randomElement()!
            
            let description: String
            switch type {
            case .sent: description = "Sent \(token)"
            case .received: description = "Received \(token)"
            case .swap: description = "Swapped \(token) for USDC"
            case .contractInteraction: description = "Contract Interaction"
            case .approval: description = "Approved \(token)"
            }
            
            return Transaction(
                type: type,
                status: status,
                description: description,
                amount: Double.random(in: 0.001...10),
                tokenSymbol: token,
                usdValue: "$\(Double.random(in: 10...10000).rounded(to: 2))",
                date: Date().addingTimeInterval(-Double(index + offset) * 3600 * 6),
                chainId: 1,
                chainName: "Ethereum",
                hash: "0x\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())",
                from: "0x742d35Cc6634C0532925a3b844Bc9e7595f8fA9e",
                to: "0x89205A3A3b2A69De6Dbf7f01ED13B2108B2c43e7",
                gasFee: Double.random(in: 1...20)
            )
        }
    }
    
    private func groupTransactionsByDate(_ transactions: [Transaction]) -> [TransactionGroup] {
        let grouped = Dictionary(grouping: transactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
        
        return grouped.map { TransactionGroup(date: $0.key, transactions: $0.value) }
            .sorted { $0.date > $1.date }
    }
}

// MARK: - String Extensions
extension String {
    var truncatedAddress: String {
        guard count > 10 else { return self }
        return "\(prefix(6))...\(suffix(4))"
    }
    
    var truncatedHash: String {
        guard count > 10 else { return self }
        return "\(prefix(10))...\(suffix(6))"
    }
}