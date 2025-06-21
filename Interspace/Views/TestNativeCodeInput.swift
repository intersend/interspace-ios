import SwiftUI

struct TestNativeCodeInput: View {
    @State private var code = ""
    @State private var showResult = false
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Test Native Code Input")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Enter 6-digit code")
                .font(.headline)
                .foregroundColor(.secondary)
            
            NativeCodeInput(
                code: $code,
                onComplete: {
                    showResult = true
                }
            )
            
            Text("Current code: \(code)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if showResult {
                Text("Code Complete! ✅")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            
            Button("Reset") {
                code = ""
                showResult = false
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    TestNativeCodeInput()
}