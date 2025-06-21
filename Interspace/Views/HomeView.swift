import SwiftUI

// This is a placeholder HomeView that's no longer used in the main app
// The main interface now uses TabView with ProfilesView, AppsView, and WalletView
struct HomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Home")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This view is deprecated. The app now uses tab-based navigation.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}