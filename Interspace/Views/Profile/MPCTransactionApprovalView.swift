import SwiftUI
import LocalAuthentication

// MARK: - MPCTransactionApprovalView

struct MPCTransactionApprovalView: View {
    let transaction: MPCTransaction
    let onApprove: () async throws -> Void
    let onReject: () -> Void
    
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var biometricAuthenticated = false
    @State private var showDetails = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Transaction Summary
                        transactionSummaryCard
                        
                        // Security Verification
                        if !biometricAuthenticated {
                            securityVerificationCard
                        } else {
                            verifiedCard
                        }
                        
                        // Transaction Details
                        if showDetails {
                            transactionDetailsCard
                        }
                        
                        // Toggle Details Button
                        Button {
                            withAnimation {
                                showDetails.toggle()
                            }
                        } label: {
                            HStack {
                                Text(showDetails ? "Hide Details" : "Show Details")
                                    .font(.system(size: 14, weight: .medium))
                                Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(DesignTokens.Colors.primary)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                }
                
                // Action Buttons
                actionButtons
                    .padding()
            }
        }
        .alert("Transaction Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var headerView: some View {
        HStack {
            Button {
                onReject()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Approve Transaction")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Placeholder for balance
            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding()
        .background(
            Color.black.opacity(0.3)
                .background(.ultraThinMaterial)
        )
    }
    
    private var transactionSummaryCard: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: transaction.type.icon)
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Colors.primary)
                .padding()
                .background(
                    Circle()
                        .fill(DesignTokens.Colors.primary.opacity(0.1))
                )
            
            // Type
            Text(transaction.type.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            // Amount (if applicable)
            if let amount = transaction.amount,
               let token = transaction.token {
                VStack(spacing: 8) {
                    Text(amount)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(token)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Recipient
            if let recipient = transaction.recipient {
                VStack(spacing: 8) {
                    Text("To")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(recipient)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var securityVerificationCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lock.shield")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                Text("Security Verification Required")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text("Authenticate with \(BiometricAuthManager.shared.getBiometryTypeString()) to approve this transaction")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            Button {
                Task {
                    await authenticateWithBiometrics()
                }
            } label: {
                Label(
                    "Authenticate",
                    systemImage: BiometricAuthManager.shared.getBiometryIcon()
                )
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(DesignTokens.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var verifiedCard: some View {
        HStack {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
            
            Text("Identity Verified")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var transactionDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transaction Details")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                DetailRow(title: "Network", value: transaction.network)
                
                if let gasEstimate = transaction.gasEstimate {
                    DetailRow(title: "Estimated Gas", value: gasEstimate)
                }
                
                DetailRow(title: "Nonce", value: "\(transaction.nonce ?? 0)")
                
                if let data = transaction.data {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(data)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.05))
                            )
                    }
                }
                
                DetailRow(
                    title: "Timestamp",
                    value: DateFormatter.localizedString(
                        from: Date(),
                        dateStyle: .medium,
                        timeStyle: .short
                    )
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                onReject()
                dismiss()
            } label: {
                Text("Reject")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Button {
                Task {
                    await approveTransaction()
                }
            } label: {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Approve")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(biometricAuthenticated ? DesignTokens.Colors.primary : Color.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(!biometricAuthenticated || isProcessing)
        }
    }
    
    private func authenticateWithBiometrics() async {
        do {
            try await BiometricAuthManager.shared.authenticate(
                reason: "Authenticate to approve transaction"
            )
            withAnimation {
                biometricAuthenticated = true
            }
            HapticManager.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            HapticManager.notification(.error)
        }
    }
    
    private func approveTransaction() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await onApprove()
            HapticManager.notification(.success)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            HapticManager.notification(.error)
        }
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Transaction Model

struct MPCTransaction {
    let id: String
    let type: TransactionType
    let amount: String?
    let token: String?
    let recipient: String?
    let network: String
    let gasEstimate: String?
    let nonce: Int?
    let data: String?
    let messageToSign: Data
    
    enum TransactionType {
        case send
        case swap
        case approve
        case signMessage
        case contractInteraction
        
        var displayName: String {
            switch self {
            case .send: return "Send Transaction"
            case .swap: return "Token Swap"
            case .approve: return "Token Approval"
            case .signMessage: return "Sign Message"
            case .contractInteraction: return "Contract Interaction"
            }
        }
        
        var icon: String {
            switch self {
            case .send: return "paperplane.fill"
            case .swap: return "arrow.triangle.2.circlepath"
            case .approve: return "checkmark.shield.fill"
            case .signMessage: return "signature"
            case .contractInteraction: return "doc.text.fill"
            }
        }
    }
}

// MARK: - Preview

struct MPCTransactionApprovalView_Previews: PreviewProvider {
    static var previews: some View {
        MPCTransactionApprovalView(
            transaction: MPCTransaction(
                id: "1",
                type: .send,
                amount: "0.5",
                token: "ETH",
                recipient: "0x1234...5678",
                network: "Ethereum Mainnet",
                gasEstimate: "0.002 ETH",
                nonce: 42,
                data: nil,
                messageToSign: Data()
            ),
            onApprove: { },
            onReject: { }
        )
    }
}