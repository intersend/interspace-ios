import SwiftUI

struct TestGlassEffectView: View {
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Test different glass effects
                Text("Ultra Thin Glass")
                    .padding()
                    .glassEffect(.ultraThin, in: .rect(cornerRadius: 16))
                
                Text("Thin Glass with Tint")
                    .padding()
                    .glassEffect(.thin.tint(.green), in: .rect(cornerRadius: 16))
                
                Text("Regular Interactive Glass")
                    .padding()
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                
                Text("Thick Glass")
                    .padding()
                    .glassEffect(.thick, in: .rect(cornerRadius: 16))
                
                Text("Capsule Glass")
                    .padding()
                    .glassEffect(.regular.tint(.orange), in: .capsule)
                
                // Test liquid glass card
                VStack {
                    Text("Liquid Glass Card")
                        .font(.headline)
                    Text("This is a card with liquid glass styling")
                        .font(.caption)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .liquidGlassCard()
            }
            .padding()
        }
    }
}

struct TestGlassEffectView_Previews: PreviewProvider {
    static var previews: some View {
        TestGlassEffectView()
            .preferredColorScheme(.dark)
    }
}