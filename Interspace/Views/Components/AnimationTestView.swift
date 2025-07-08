import SwiftUI

// MARK: - Animation Test View
// Use this view to test and preview all animation components

struct AnimationTestView: View {
    @State private var showSendSheet = false
    @State private var showReceiveSheet = false
    @State private var showSwapSheet = false
    @State private var testValue: Double = 0
    @State private var showShimmer = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Sheet Test Buttons
                        Group {
                            testButton(title: "Test Send Sheet", icon: "paperplane.fill") {
                                showSendSheet = true
                            }
                            
                            testButton(title: "Test Receive Sheet", icon: "qrcode") {
                                showReceiveSheet = true
                            }
                            
                            testButton(title: "Test Swap Sheet", icon: "arrow.left.arrow.right") {
                                showSwapSheet = true
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        // Animation Component Tests
                        Group {
                            // Number Ticker Test
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Number Ticker Test")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                NumberTickerView(
                                    value: testValue,
                                    format: "$%.2f",
                                    font: .system(size: 24, weight: .bold),
                                    color: .white
                                )
                                
                                Button("Random Value") {
                                    withAnimation {
                                        testValue = Double.random(in: 0...10000)
                                    }
                                }
                                .buttonStyle(SimpleLiquidGlassButtonStyle(isProminent: true))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Material.ultraThinMaterial)
                            )
                            
                            // Shimmer Effect Test
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Shimmer Effect Test")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Loading...")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                    .shimmer()
                                    .opacity(showShimmer ? 1 : 0)
                                
                                Button("Toggle Shimmer") {
                                    showShimmer.toggle()
                                }
                                .buttonStyle(LiquidGlassButtonStyle())
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Material.ultraThinMaterial)
                            )
                            
                            // Success Animation Test
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Success Animation Test")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Button("Show Success") {
                                    showSuccess = true
                                }
                                .buttonStyle(LiquidGlassButtonStyle(isProminent: true, tint: .green))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Material.ultraThinMaterial)
                            )
                        }
                        
                        // Animated List Test
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Animated List Test")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ForEach(0..<5) { index in
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    Text("Item \(index + 1)")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .animatedListItem(index: index)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Material.ultraThinMaterial)
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Animation Tests")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showSendSheet) {
            SendTokenSheetEnhanced()
        }
        .sheet(isPresented: $showReceiveSheet) {
            ReceiveTokenSheetEnhanced()
        }
        .sheet(isPresented: $showSwapSheet) {
            SwapTokenSheetEnhanced()
        }
        .overlay {
            if showSuccess {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                SuccessAnimationView {
                    showSuccess = false
                }
            }
        }
    }
    
    private func testButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .opacity(0.5)
            }
            .foregroundColor(.white)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Material.ultraThinMaterial)
            )
        }
        .animatedButton()
    }
}

// MARK: - Preview
#Preview("Animation Tests") {
    AnimationTestView()
        .environmentObject(WalletViewModel())
        .environmentObject(ProfileViewModel())
}

// MARK: - Animation Debugging Tips
/*
 1. Use the Debug View Hierarchy to inspect animation states
 2. Enable Slow Animations in Simulator (Debug > Slow Animations)
 3. Use Console logs to track animation timings
 4. Test on both light and dark modes
 5. Verify on different device sizes
 6. Check memory usage during animations
 7. Test with VoiceOver enabled for accessibility
 */