import Foundation
import Combine
import UIKit

/// Service to handle transaction routing from dApps to user's wallet
/// When dApps request transactions, routes them to the user's actual wallet for execution
@MainActor
final class TransactionApprovalService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = TransactionApprovalService()
    
    // MARK: - Published Properties
    
    @Published var pendingTransaction: PendingTransaction?
    @Published var isProcessing = false
    @Published var error: Error?
    
    // MARK: - Properties
    
    private let walletService = WalletServiceV2.shared
    private let profileViewModel = ProfileViewModel.shared
    private var pendingCompletion: ((Result<String, Error>) -> Void)?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Route a transaction request from a dApp to the user's wallet
    /// - Parameters:
    ///   - params: Web3 transaction parameters from the dApp
    ///   - mpcAddress: The MPC wallet address that the dApp sees
    ///   - profile: The active SmartProfile
    /// - Returns: Transaction hash after execution
    func routeTransaction(
        params: [String: Any],
        mpcAddress: String,
        profile: SmartProfile
    ) async throws -> String {
        // Convert web3 params to transaction
        guard let transaction = WalletTransaction.from(web3Params: params) else {
            throw TransactionError.invalidParams
        }
        
        // Get the user's linked wallet
        guard let linkedWallet = getActiveLinkedWallet(for: profile) else {
            throw TransactionError.noLinkedWallet
        }
        
        // Replace the 'from' address with the user's actual wallet address
        let userTransaction = WalletTransaction(
            from: linkedWallet.address,
            to: transaction.to,
            value: transaction.value,
            data: transaction.data,
            gasLimit: transaction.gasLimit,
            gasPrice: transaction.gasPrice,
            nonce: transaction.nonce,
            chainId: transaction.chainId
        )
        
        // Create pending transaction
        let pending = PendingTransaction(
            id: UUID().uuidString,
            transaction: userTransaction,
            originalFrom: mpcAddress,
            linkedWallet: linkedWallet,
            profile: profile,
            createdAt: Date()
        )
        
        // Update state
        pendingTransaction = pending
        isProcessing = true
        error = nil
        
        return try await withCheckedThrowingContinuation { continuation in
            pendingCompletion = { result in
                Task { @MainActor in
                    self.isProcessing = false
                    self.pendingTransaction = nil
                    
                    switch result {
                    case .success(let txHash):
                        continuation.resume(returning: txHash)
                    case .failure(let error):
                        self.error = error
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // Show transaction preview and route to wallet
            Task {
                await showTransactionPreview(for: pending)
            }
        }
    }
    
    /// Approve and send the transaction to the user's wallet
    func approvePendingTransaction() async throws {
        guard let pending = pendingTransaction else {
            throw TransactionError.noPendingTransaction
        }
        
        do {
            // Send transaction using the user's linked wallet
            let txHash = try await walletService.sendTransaction(
                pending.transaction,
                walletType: pending.linkedWallet.type
            )
            
            // Success
            pendingCompletion?(.success(txHash))
            
        } catch {
            pendingCompletion?(.failure(error))
            throw error
        }
    }
    
    /// Reject the pending transaction
    func rejectPendingTransaction() {
        pendingCompletion?(.failure(TransactionError.userRejected))
        pendingTransaction = nil
        isProcessing = false
    }
    
    /// Sign a message using the user's linked wallet
    /// - Parameters:
    ///   - message: The message to sign
    ///   - mpcAddress: The MPC address (for context)
    ///   - profile: The active profile
    /// - Returns: The signature from the user's wallet
    func signMessage(
        _ message: String,
        mpcAddress: String,
        profile: SmartProfile
    ) async throws -> String {
        // Get the user's linked wallet
        guard let linkedWallet = getActiveLinkedWallet(for: profile) else {
            throw TransactionError.noLinkedWallet
        }
        
        // Sign with the user's wallet
        let signature = try await walletService.signMessage(
            message,
            walletType: linkedWallet.type
        )
        
        return signature.normalizedSignature
    }
    
    // MARK: - Private Methods
    
    private func getActiveLinkedWallet(for profile: SmartProfile) -> LinkedWallet? {
        // Get the active linked wallet from profile
        // Since SmartProfile doesn't directly contain linked accounts,
        // we need to check ProfileViewModel
        
        let linkedAccounts = profileViewModel.linkedAccounts
        
        // Find wallet accounts
        let walletAccounts = linkedAccounts.filter { $0.authStrategy == "wallet" }
        
        // Get the active wallet (first one for now, could be user preference)
        guard let activeAccount = walletAccounts.first else {
            return nil
        }
        
        // Determine wallet type from the walletType property
        let walletTypeString = activeAccount.walletType ?? ""
        let walletType = WalletType(rawValue: walletTypeString) ?? .unknown
        
        return LinkedWallet(
            address: activeAccount.address,
            type: walletType,
            name: activeAccount.customName ?? walletType.displayName
        )
    }
    
    private func showTransactionPreview(for pending: PendingTransaction) async {
        // Present the transaction preview UI
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            pendingCompletion?(.failure(TransactionError.uiError("No root view controller")))
            return
        }
        
        // Find the top-most presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        // Create and present transaction preview
        let previewView = TransactionPreviewView(
            transaction: pending,
            onApprove: { [weak self] in
                Task {
                    try? await self?.approvePendingTransaction()
                }
            },
            onReject: { [weak self] in
                self?.rejectPendingTransaction()
            }
        )
        
        let hostingController = UIHostingController(rootView: previewView)
        hostingController.modalPresentationStyle = .pageSheet
        
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        
        topController.present(hostingController, animated: true)
    }
}

// MARK: - Supporting Types

/// Pending transaction information
struct PendingTransaction: Identifiable {
    let id: String
    let transaction: WalletTransaction  // Transaction with user's wallet as 'from'
    let originalFrom: String            // Original MPC address from dApp
    let linkedWallet: LinkedWallet
    let profile: SmartProfile
    let createdAt: Date
}

/// Linked wallet information
struct LinkedWallet {
    let address: String
    let type: WalletType
    let name: String
}

/// Transaction errors
enum TransactionError: LocalizedError {
    case invalidParams
    case noLinkedWallet
    case noPendingTransaction
    case userRejected
    case walletError(String)
    case uiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidParams:
            return "Invalid transaction parameters"
        case .noLinkedWallet:
            return "No wallet linked to this profile"
        case .noPendingTransaction:
            return "No pending transaction"
        case .userRejected:
            return "Transaction rejected"
        case .walletError(let reason):
            return "Wallet error: \(reason)"
        case .uiError(let reason):
            return "UI error: \(reason)"
        }
    }
}

// MARK: - Transaction Preview UI

import SwiftUI

/// Transaction preview view for user approval
struct TransactionPreviewView: View {
    let transaction: PendingTransaction
    let onApprove: () -> Void
    let onReject: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Confirm Transaction")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("Review and approve in \(transaction.linkedWallet.name)")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                // Transaction details
                VStack(spacing: 16) {
                    detailRow(label: "From", value: transaction.linkedWallet.address)
                    detailRow(label: "To", value: transaction.transaction.to)
                    
                    if let value = transaction.transaction.value, value != "0x0" {
                        detailRow(label: "Value", value: formatValue(value))
                    }
                    
                    if let data = transaction.transaction.data, data != "0x" {
                        detailRow(label: "Data", value: "Present")
                    }
                    
                    detailRow(label: "Network", value: chainName(transaction.transaction.chainId))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(Color.gray.opacity(0.1))
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    Button {
                        onApprove()
                        dismiss()
                    } label: {
                        Text("Open \(transaction.linkedWallet.name)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.blue)
                            )
                    }
                    
                    Button {
                        onReject()
                        dismiss()
                    } label: {
                        Text("Reject")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onReject()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
    
    private func formatValue(_ hex: String) -> String {
        // Simple formatting - in production would convert to ETH
        return hex
    }
    
    private func chainName(_ chainId: Int) -> String {
        switch chainId {
        case 1: return "Ethereum"
        case 137: return "Polygon"
        case 10: return "Optimism"
        case 42161: return "Arbitrum"
        default: return "Chain \(chainId)"
        }
    }
}
