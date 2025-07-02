import SwiftUI

struct AccountDetailViewV2: View {
    let account: AccountV2
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isAddressHidden = false
    @State private var showCopiedFeedback = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                List {
                    // Account Info Section
                    Section {
                        HStack(spacing: 16) {
                            // Account Icon
                            accountIcon
                                .font(.system(size: 24))
                                .foregroundColor(accountColor)
                                .frame(width: 48, height: 48)
                                .background(
                                    Circle()
                                        .fill(accountColor.opacity(0.15))
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayName)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 8) {
                                    Text(displayIdentifier)
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    if account.accountType == "wallet" {
                                        // Copy button for wallet addresses
                                        Button(action: {
                                            UIPasteboard.general.string = account.identifier
                                            HapticManager.notification(.success)
                                            withAnimation {
                                                showCopiedFeedback = true
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                withAnimation {
                                                    showCopiedFeedback = false
                                                }
                                            }
                                        }) {
                                            Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                                .font(.system(size: 12))
                                                .foregroundColor(showCopiedFeedback ? .green : .gray)
                                        }
                                    }
                                }
                                
                                if account.verified {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.green)
                                        Text("Verified")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                    
                    // Account Details Section
                    Section(header: Text("DETAILS")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)) {
                        
                        // Account Type
                        HStack {
                            Text("Type")
                            Spacer()
                            Text(account.accountType.capitalized)
                                .foregroundColor(.gray)
                        }
                        
                        // Provider (for social accounts)
                        if let provider = account.provider {
                            HStack {
                                Text("Provider")
                                Spacer()
                                Text(provider.capitalized)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Created Date
                        HStack {
                            Text("Added")
                            Spacer()
                            Text(formatDate(account.createdAt))
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                    
                    // Danger Zone
                    Section(header: Text("DANGER ZONE")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)) {
                        
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "link.badge.minus")
                                    .font(.system(size: 16))
                                Text("Unlink Account")
                                Spacer()
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                }
                .listStyle(InsetGroupedListStyle())
                .preferredColorScheme(.dark)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .alert("Unlink Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Unlink", role: .destructive) {
                Task {
                    await viewModel.unlinkAccount(account)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to unlink this \(account.accountType) account? You can always link it again later.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var accountIcon: Image {
        switch account.accountType {
        case "email":
            return Image(systemName: "envelope.fill")
        case "wallet":
            return Image(systemName: "wallet.pass.fill")
        case "social":
            return socialIcon
        default:
            return Image(systemName: "person.fill")
        }
    }
    
    private var socialIcon: Image {
        switch account.provider?.lowercased() {
        case "google":
            return Image(systemName: "g.circle.fill")
        case "apple":
            return Image(systemName: "apple.logo")
        case "github":
            return Image(systemName: "chevron.left.forwardslash.chevron.right")
        case "twitter":
            return Image(systemName: "bird.fill")
        default:
            return Image(systemName: "person.circle.fill")
        }
    }
    
    private var accountColor: Color {
        switch account.accountType {
        case "email":
            return .blue
        case "wallet":
            return .orange
        case "social":
            return socialColor
        default:
            return .gray
        }
    }
    
    private var socialColor: Color {
        switch account.provider?.lowercased() {
        case "google":
            return .red
        case "apple":
            return .white
        case "github":
            return .gray
        case "twitter":
            return .blue
        default:
            return .purple
        }
    }
    
    private var displayName: String {
        if account.accountType == "email" {
            return "Email Account"
        } else if account.accountType == "wallet" {
            // Extract wallet type from metadata if available
            if let walletType = account.metadata?["walletType"] as? String {
                return walletType.capitalized + " Wallet"
            }
            return "Wallet"
        } else if account.accountType == "social" {
            return account.provider?.capitalized ?? "Social Account"
        }
        return account.accountType.capitalized
    }
    
    private var displayIdentifier: String {
        if account.accountType == "wallet" && isAddressHidden {
            return maskedAddress(account.identifier)
        }
        return account.identifier
    }
    
    private func maskedAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        let prefix = address.prefix(6)
        let suffix = address.suffix(4)
        return "\(prefix)••••\(suffix)"
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        
        return displayFormatter.string(from: date)
    }
}

// MARK: - Preview

struct AccountDetailViewV2_Previews: PreviewProvider {
    static var previews: some View {
        AccountDetailViewV2(
            account: AccountV2(
                id: "1",
                accountType: "email",
                identifier: "test@example.com",
                provider: nil,
                metadata: [:],
                verified: true,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            ),
            viewModel: ProfileViewModel.shared
        )
        .preferredColorScheme(.dark)
    }
}