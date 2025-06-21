import SwiftUI

struct TransactionHistoryView: View {
    @StateObject private var viewModel = WalletViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTransaction: TransactionHistory.TransactionItem?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                DesignTokens.Colors.backgroundSecondary
                    .ignoresSafeArea(.all)
                
                if let history = viewModel.transactionHistory, !history.transactions.isEmpty {
                    List {
                        ForEach(history.transactions) { transaction in
                            TransactionRow(transaction: transaction) {
                                selectedTransaction = transaction
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                            .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .onAppear {
                                // Load more when reaching near the end
                                if transaction.id == history.transactions.last?.id {
                                    Task {
                                        await viewModel.loadMoreTransactions()
                                    }
                                }
                            }
                        }
                        
                        // Loading indicator for pagination
                        if history.pagination.hasNext && viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.primary))
                                Spacer()
                            }
                            .padding()
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await viewModel.loadTransactionHistory()
                    }
                } else if viewModel.isLoading {
                    // Loading state
                    VStack(spacing: DesignTokens.Spacing.md) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.primary))
                            .scaleEffect(1.2)
                        
                        Text("Loading transactions...")
                            .font(DesignTokens.Typography.bodyMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                } else {
                    // Empty state
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                        
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            Text("No Transactions Yet")
                                .font(DesignTokens.Typography.headlineSmall)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            
                            Text("Your transaction history will appear here")
                                .font(DesignTokens.Typography.bodyMedium)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.xxxl)
                }
            }
            .navigationTitle("Transaction History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.Colors.primary)
                }
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
        }
        .onAppear {
            Task {
                await viewModel.loadTransactionHistory()
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: TransactionHistory.TransactionItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Transaction icon
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                // Transaction details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(transactionTitle)
                            .font(DesignTokens.Typography.bodyMedium)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        Spacer()
                        
                        Text(transactionAmount)
                            .font(DesignTokens.Typography.bodyMedium)
                            .foregroundColor(amountColor)
                    }
                    
                    HStack {
                        Text(formattedDate)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        
                        Spacer()
                        
                        StatusBadge(status: transaction.status)
                    }
                    
                    if let fromAddress = transaction.from?.address,
                       let toAddress = transaction.to?.address {
                        HStack {
                            Text(formatAddress(fromAddress))
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                            
                            Text(formatAddress(toAddress))
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.GlassEffect.ultraThin)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Computed Properties
    
    private var transactionTitle: String {
        switch transaction.type.lowercased() {
        case "send":
            return "Sent"
        case "receive":
            return "Received"
        case "swap":
            return "Swapped"
        case "approve":
            return "Approved"
        default:
            return transaction.type.capitalized
        }
    }
    
    private var transactionAmount: String {
        if let amount = transaction.from?.amount,
           let token = transaction.from?.token {
            return "\(formatAmount(amount)) \(token)"
        } else if let amount = transaction.to?.amount,
                  let token = transaction.to?.token {
            return "\(formatAmount(amount)) \(token)"
        }
        return ""
    }
    
    private var iconName: String {
        switch transaction.type.lowercased() {
        case "send":
            return "arrow.up"
        case "receive":
            return "arrow.down"
        case "swap":
            return "arrow.left.arrow.right"
        case "approve":
            return "checkmark.circle"
        default:
            return "arrow.left.arrow.right"
        }
    }
    
    private var iconColor: Color {
        switch transaction.type.lowercased() {
        case "send":
            return .red
        case "receive":
            return DesignTokens.Colors.success
        case "swap":
            return .orange
        case "approve":
            return DesignTokens.Colors.primary
        default:
            return DesignTokens.Colors.textSecondary
        }
    }
    
    private var iconBackgroundColor: Color {
        iconColor.opacity(0.15)
    }
    
    private var amountColor: Color {
        switch transaction.type.lowercased() {
        case "send":
            return .red
        case "receive":
            return DesignTokens.Colors.success
        default:
            return DesignTokens.Colors.textPrimary
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: transaction.createdAt) {
            return formatter.string(from: date)
        }
        return transaction.createdAt
    }
    
    // MARK: - Helper Methods
    
    private func formatAmount(_ amount: String) -> String {
        if let doubleValue = Double(amount) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 6
            return formatter.string(from: NSNumber(value: doubleValue)) ?? amount
        }
        return amount
    }
    
    private func formatAddress(_ address: String) -> String {
        let prefix = address.prefix(6)
        let suffix = address.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.capitalized)
            .font(DesignTokens.Typography.labelSmall)
            .foregroundColor(statusColor)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.15))
            .cornerRadius(DesignTokens.CornerRadius.sm)
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "completed", "success":
            return DesignTokens.Colors.success
        case "pending":
            return .orange
        case "failed", "error":
            return DesignTokens.Colors.error
        default:
            return DesignTokens.Colors.textSecondary
        }
    }
}

// MARK: - Transaction Detail View

struct TransactionDetailView: View {
    let transaction: TransactionHistory.TransactionItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Transaction Header
                    VStack(spacing: DesignTokens.Spacing.md) {
                        StatusBadge(status: transaction.status)
                        
                        Text(transaction.type.capitalized)
                            .font(DesignTokens.Typography.headlineLarge)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        
                        if let amount = transaction.from?.amount,
                           let token = transaction.from?.token {
                            Text("\(formatAmount(amount)) \(token)")
                                .font(DesignTokens.Typography.headlineSmall)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.lg)
                    
                    // Transaction Details
                    VStack(spacing: DesignTokens.Spacing.md) {
                        DetailRow(title: "Transaction ID", value: transaction.operationSetId, copyable: true)
                        
                        if let fromAddress = transaction.from?.address {
                            DetailRow(title: "From", value: fromAddress, copyable: true)
                        }
                        
                        if let toAddress = transaction.to?.address {
                            DetailRow(title: "To", value: toAddress, copyable: true)
                        }
                        
                        if let gasToken = transaction.gasToken {
                            DetailRow(title: "Gas Token", value: gasToken, copyable: false)
                        }
                        
                        DetailRow(title: "Created", value: formattedDate(transaction.createdAt), copyable: false)
                        
                        if let completedAt = transaction.completedAt {
                            DetailRow(title: "Completed", value: formattedDate(completedAt), copyable: false)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                    
                    // On-chain Transactions
                    if !transaction.transactions.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            Text("On-chain Transactions")
                                .font(DesignTokens.Typography.headlineSmall)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                                .padding(.horizontal, DesignTokens.Spacing.screenPadding)
                            
                            ForEach(Array(transaction.transactions.enumerated()), id: \.offset) { index, tx in
                                OnChainTransactionRow(transaction: tx, index: index + 1)
                            }
                        }
                    }
                    
                    Spacer(minLength: DesignTokens.Spacing.xl)
                }
            }
            .background(DesignTokens.Colors.backgroundSecondary)
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignTokens.Colors.primary)
                }
            }
        }
    }
    
    private func formatAmount(_ amount: String) -> String {
        if let doubleValue = Double(amount) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 6
            return formatter.string(from: NSNumber(value: doubleValue)) ?? amount
        }
        return amount
    }
    
    private func formattedDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return formatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let title: String
    let value: String
    let copyable: Bool
    
    @State private var showCopied = false
    
    init(title: String, value: String, copyable: Bool = false) {
        self.title = title
        self.value = value
        self.copyable = copyable
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            
            HStack {
                Text(displayValue)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(nil)
                
                Spacer()
                
                if copyable {
                    Button(action: copyToClipboard) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(showCopied ? DesignTokens.Colors.success : DesignTokens.Colors.textTertiary)
                    }
                    .animation(.easeInOut(duration: 0.2), value: showCopied)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.GlassEffect.ultraThin)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 0.5)
        )
    }
    
    private var displayValue: String {
        if value.count > 42 && value.hasPrefix("0x") {
            // Format as address
            let prefix = value.prefix(10)
            let suffix = value.suffix(8)
            return "\(prefix)...\(suffix)"
        }
        return value
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = value
        showCopied = true
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showCopied = false
        }
    }
}

// MARK: - On-chain Transaction Row

struct OnChainTransactionRow: View {
    let transaction: TransactionHistory.TransactionItem.OnChainTransaction
    let index: Int
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Chain indicator
            ZStack {
                Circle()
                    .fill(DesignTokens.Colors.primary.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Text("\(index)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(DesignTokens.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Chain ID: \(transaction.chainId)")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text(formatHash(transaction.hash))
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            StatusBadge(status: transaction.status)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.GlassEffect.ultraThin)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 0.5)
        )
        .padding(.horizontal, DesignTokens.Spacing.screenPadding)
    }
    
    private func formatHash(_ hash: String) -> String {
        let prefix = hash.prefix(10)
        let suffix = hash.suffix(8)
        return "\(prefix)...\(suffix)"
    }
}

// MARK: - Preview

struct TransactionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionHistoryView()
            .preferredColorScheme(.dark)
    }
}