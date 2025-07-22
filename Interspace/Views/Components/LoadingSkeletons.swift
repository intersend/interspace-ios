import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerEffect: View {
    @State private var isAnimating = false
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(white: 0.15),
                Color(white: 0.25),
                Color(white: 0.15)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .rotationEffect(.degrees(-25))
        .offset(x: isAnimating ? 300 : -300)
        .animation(
            Animation.linear(duration: 1.5)
                .repeatForever(autoreverses: false),
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Profile Skeleton

struct ProfileSkeletonRow: View {
    var body: some View {
        HStack(spacing: 16) {
            // Avatar skeleton
            Circle()
                .fill(Color(white: 0.15))
                .frame(width: 50, height: 50)
                .overlay(ShimmerEffect().mask(Circle()))
            
            VStack(alignment: .leading, spacing: 8) {
                // Name skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.15))
                    .frame(width: 120, height: 16)
                    .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 4)))
                
                // Wallet address skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.15))
                    .frame(width: 180, height: 12)
                    .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 4)))
            }
            
            Spacer()
            
            // Chevron skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(white: 0.15))
                .frame(width: 8, height: 14)
                .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 4)))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Account Skeleton

struct AccountSkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            // Icon skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.15))
                .frame(width: 40, height: 40)
                .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 8)))
            
            VStack(alignment: .leading, spacing: 6) {
                // Type skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.15))
                    .frame(width: 80, height: 14)
                    .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 4)))
                
                // Identifier skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.15))
                    .frame(width: 140, height: 12)
                    .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 4)))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Loading List

struct LoadingListView: View {
    let itemCount: Int
    let itemBuilder: () -> AnyView
    
    init(itemCount: Int = 3, @ViewBuilder itemBuilder: @escaping () -> some View) {
        self.itemCount = itemCount
        self.itemBuilder = { AnyView(itemBuilder()) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<itemCount, id: \.self) { index in
                itemBuilder()
                
                if index < itemCount - 1 {
                    Divider()
                        .padding(.leading, 20)
                }
            }
        }
        .background(Color(white: 0.08))
        .cornerRadius(12)
    }
}

// MARK: - Connection Loading View

struct ConnectionLoadingView: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    
    @State private var dots = ""
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(iconColor)
            }
            
            VStack(spacing: 8) {
                Text(title + dots)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            // Progress indicator
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: iconColor))
                .scaleEffect(1.2)
        }
        .onAppear {
            startDotsAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startDotsAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if dots.count >= 3 {
                dots = ""
            } else {
                dots += "."
            }
        }
    }
}

// MARK: - Native Activity Indicator

struct NativeLoadingView: View {
    let message: String?
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            if let message = message {
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.1))
        )
    }
}

// MARK: - Loading Button State

struct LoadingButtonStyle: ButtonStyle {
    let isLoading: Bool
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isLoading ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed && !isLoading ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - NFT Skeleton Components

struct NFTSkeletonView: View {
    let itemCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.15))
                    .frame(width: 60, height: 22)
                    .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 4)))
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.15))
                    .frame(width: 32, height: 20)
                    .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 12)))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // NFT Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0..<itemCount, id: \.self) { _ in
                    NFTGridItemSkeleton()
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct NFTGridItemSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // NFT Image
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.15))
                .aspectRatio(1, contentMode: .fit)
                .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 12)))
            
            // NFT Info
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.15))
                    .frame(height: 14)
                    .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 4)))
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.15))
                    .frame(width: 60, height: 12)
                    .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 4)))
            }
        }
    }
}

struct NFTCollectionSkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Collection Header
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.15))
                    .frame(width: 120, height: 18)
                    .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 4)))
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.15))
                    .frame(width: 50, height: 14)
                    .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 4)))
            }
            
            // Horizontal NFT Items
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        NFTCollectionItemSkeleton()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

struct NFTCollectionItemSkeleton: View {
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.15))
                .frame(width: 140, height: 140)
                .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 12)))
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(white: 0.15))
                .frame(width: 100, height: 12)
                .overlay(ShimmerEffect().mask(RoundedRectangle(cornerRadius: 4)))
        }
    }
}

// MARK: - Preview

struct LoadingSkeletons_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Profile skeletons
                LoadingListView(itemCount: 3) {
                    ProfileSkeletonRow()
                }
                .padding(.horizontal)
                
                // Account skeletons
                LoadingListView(itemCount: 2) {
                    AccountSkeletonRow()
                }
                .padding(.horizontal)
                
                // Connection loading
                ConnectionLoadingView(
                    title: "Connecting",
                    subtitle: "Opening wallet app",
                    icon: "wallet.pass",
                    iconColor: .orange
                )
                
                // Native loading
                NativeLoadingView(message: "Loading profiles...")
                
                // NFT skeletons
                NFTSkeletonView(itemCount: 4)
                    .padding(.top)
            }
        }
        .preferredColorScheme(.dark)
    }
}