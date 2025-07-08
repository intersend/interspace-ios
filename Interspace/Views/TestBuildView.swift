import SwiftUI

// Test view to verify all components compile correctly
struct TestBuildView: View {
    @StateObject private var walletViewModel = WalletViewModel()
    @State private var showSend = false
    @State private var showReceive = false
    @State private var showSwap = false
    
    var body: some View {
        VStack {
            Button("Test Send") { showSend = true }
            Button("Test Receive") { showReceive = true }
            Button("Test Swap") { showSwap = true }
        }
        .sheet(isPresented: $showSend) {
            SendTokenSheet()
                .environmentObject(walletViewModel)
        }
        .sheet(isPresented: $showReceive) {
            ReceiveTokenSheet()
                .environmentObject(walletViewModel)
                .environmentObject(ProfileViewModel())
        }
        .sheet(isPresented: $showSwap) {
            SwapTokenSheet()
                .environmentObject(walletViewModel)
        }
    }
}

#Preview {
    TestBuildView()
}