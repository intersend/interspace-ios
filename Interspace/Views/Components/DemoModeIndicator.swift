import SwiftUI

struct DemoModeIndicator: View {
    @State private var isExpanded = false
    
    var body: some View {
        if DemoMode.isEnabled && DemoMode.showIndicator {
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "theatermasks.fill")
                                .foregroundColor(.white)
                            
                            Text("Demo Mode")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            if isExpanded {
                                Image(systemName: "chevron.up")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            } else {
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.purple.opacity(0.9))
                        )
                        .shadow(radius: 4)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Demo Mode Active")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            DemoFeatureRow(icon: "person.3.fill", text: "3 Demo Profiles")
                            DemoFeatureRow(icon: "square.grid.3x3.fill", text: "Pre-configured Apps")
                            DemoFeatureRow(icon: "bitcoinsign.circle.fill", text: "Mock Wallet Data")
                            DemoFeatureRow(icon: "photo.fill", text: "Sample NFTs")
                            DemoFeatureRow(icon: "arrow.left.arrow.right", text: "Transaction History")
                            DemoFeatureRow(icon: "wifi.slash", text: "Offline Mode")
                        }
                        
                        Text("All data is local and resets on app restart")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .italic()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.purple.opacity(0.9))
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
                
                Spacer()
            }
            .zIndex(999) // Ensure it appears above other content
        }
    }
}

struct DemoFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// MARK: - Preview

struct DemoModeIndicator_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            DemoModeIndicator()
        }
    }
}