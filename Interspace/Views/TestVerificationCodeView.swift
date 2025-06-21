import SwiftUI

struct TestVerificationCodeView: View {
    @State private var code = ""
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Test Verification Code Field")
                .font(.title)
            
            Text("Current Code: \(code)")
                .font(.headline)
            
            VerificationCodeField(
                code: $code,
                onComplete: {
                    print("Code completed: \(code)")
                }
            )
            
            Button("Reset") {
                code = ""
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.black)
    }
}

struct TestVerificationCodeView_Previews: PreviewProvider {
    static var previews: some View {
        TestVerificationCodeView()
            .preferredColorScheme(.dark)
    }
}