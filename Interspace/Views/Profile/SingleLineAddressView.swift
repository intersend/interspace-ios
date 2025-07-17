// SingleLineAddressView.swift
import SwiftUI
import UIKit

/// Displays a wallet address as a single line, monospaced, with a copy-to-clipboard button.
struct SingleLineAddressView: View {
    let address: String
    let maxWidth: CGFloat
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Text(address)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.gray)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: maxWidth, alignment: .leading)

            Button(action: copyToClipboard) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(copied ? .green : .primary)
                    .animation(.easeInOut(duration: 0.2), value: copied)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = address
        withAnimation(.easeInOut(duration: 0.2)) {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

#if DEBUG
#Preview {
    VStack {
        SingleLineAddressView(address: "0x1234567890abcdef1234567890abcdef12345678", maxWidth: 220)
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(10)
    }
    .padding()
}
#endif
