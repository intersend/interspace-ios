import SwiftUI

struct MPCGenerationIndicator: View {
    @Binding var isGenerating: Bool
    @State private var isAnimating = false
    
    var body: some View {
        if isGenerating {
            HStack(spacing: 12) {
                // Subtle animated icon
                Image(systemName: "lock.shield")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .opacity(isAnimating ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Securing your wallet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Generating encryption keys")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.7)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, 20)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .onAppear {
                isAnimating = true
            }
        }
    }
}

// MARK: - Completion Toast
struct MPCCompletionToast: View {
    @Binding var showToast: Bool
    
    var body: some View {
        if showToast {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                Text("Wallet secured")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            ))
            .onAppear {
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showToast = false
                    }
                }
                
                // Light haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
    }
}

// MARK: - Preview
struct MPCGenerationIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            MPCGenerationIndicator(isGenerating: .constant(true))
            
            MPCCompletionToast(showToast: .constant(true))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}