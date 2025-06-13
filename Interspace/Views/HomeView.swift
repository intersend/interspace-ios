import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        VStack {
            Text("Welcome, \(authService.user?.email ?? "User")!")
                .font(.largeTitle)
                .padding()

            Button(action: {
                authService.signOut()
            }) {
                Text("Sign Out")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthService())
    }
}