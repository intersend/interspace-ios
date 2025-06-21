import SwiftUI

struct DevelopmentModeToggle: View {
    @Binding var isEnabled: Bool
    var label: String = "Dev Mode"
    
    var body: some View {
        #if DEBUG
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 12))
                .foregroundColor(.yellow.opacity(0.8))
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.yellow.opacity(0.8))
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .scaleEffect(0.7)
                .tint(.yellow)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                .fill(Color.yellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
        #endif
    }
}


// MARK: - Preview

struct DevelopmentModeToggle_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            DevelopmentModeToggle(isEnabled: .constant(true))
            DevelopmentModeToggle(isEnabled: .constant(false))
            DevelopmentModeBadge()
        }
        .padding()
        .background(Color.black)
    }
}