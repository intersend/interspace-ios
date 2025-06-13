import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @StateObject private var authService = AuthService()

    var body: some View {
        VStack {
            Text("Interspace")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 50)

            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    // not used in this basic implementation
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        authService.handleAppleSignIn(authorization: authorization)
                    case .failure(let error):
                        authService.handleAppleSignInError(error: error)
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal)

            Button(action: {
                authService.signInWithGoogle()
            }) {
                HStack {
                    Image("google")
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("Sign in with Google")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .foregroundColor(Color.black)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
            }
            .padding()
        }
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
    }
}