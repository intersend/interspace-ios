import SwiftUI

// MARK: - App Store Row View

struct AppStoreRowView: View {
    let app: AppStoreApp
    let isAdded: Bool
    let onAdd: () async -> Void
    
    @State private var isAdding = false
    @State private var iconImage: UIImage?
    @State private var isPressed = false
    @State private var showIcon = false
    
    var body: some View {
        HStack(spacing: 16) {
            // App Icon - Apple's exact styling
            ZStack {
                RoundedRectangle(cornerRadius: 13.4)
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 60, height: 60)
                
                if let iconImage = iconImage {
                    Image(uiImage: iconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 13.4))
                        .opacity(showIcon ? 1 : 0)
                        .scaleEffect(showIcon ? 1 : 0.8)
                        .animation(.easeOut(duration: 0.3), value: showIcon)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 13.4)
                    .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
            )
            .onAppear {
                loadIcon()
            }
            
            // App Info
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(app.description)
                    .font(.system(size: 15))
                    .foregroundColor(Color(UIColor.systemGray))
                    .lineLimit(2)
            }
            
            Spacer(minLength: 16)
            
            // Add/Added Button
            Button(action: {
                guard !isAdded else { return }
                Task {
                    isAdding = true
                    await onAdd()
                    isAdding = false
                }
            }) {
                ZStack {
                    if isAdding {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.0, green: 0.478, blue: 1.0)))
                            .scaleEffect(0.8)
                    } else {
                        Text(isAdded ? "Added" : "Get")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(
                                isAdded 
                                    ? Color(UIColor.systemGray2) 
                                    : Color(red: 0.0, green: 0.478, blue: 1.0)
                            )
                    }
                }
                .frame(width: 75, height: 30)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(15)
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            }
            .disabled(isAdding || isAdded)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
            .animation(.easeInOut(duration: 0.2), value: isAdded)
        }
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.001))
    }
    
    private func loadIcon() {
        guard let iconUrl = app.iconUrl,
              let url = URL(string: iconUrl) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.iconImage = image
                        withAnimation(.easeOut(duration: 0.3)) {
                            self.showIcon = true
                        }
                    }
                }
            } catch {
                print("Failed to load icon: \(error)")
            }
        }
    }
}

// MARK: - Featured App Card

struct FeaturedAppCard: View {
    let app: AppStoreApp
    let isAdded: Bool
    let onAdd: () async -> Void
    
    @State private var isAdding = false
    @State private var backgroundImage: UIImage?
    @State private var iconImage: UIImage?
    @State private var showIcon = false
    
    var body: some View {
        ZStack {
            // Background
            GeometryReader { geometry in
                if let backgroundImage = backgroundImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: 450)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Color.pink.opacity(0.8), Color.purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            
            // Gradient overlay - starts higher up for better effect
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 280)
            }
            
            // Content
            VStack {
                HStack {
                    // Top label
                    if app.isNew {
                        Text("NOW AVAILABLE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .tracking(0.5)
                    } else if app.isFeatured {
                        Text("FEATURED")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .tracking(0.5)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Bottom section with blur effect
                VStack(spacing: 0) {
                    // Main content
                    VStack(alignment: .leading, spacing: 8) {
                        Text(app.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(app.description)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // App info bar with blur background
                    ZStack {
                        // Blur background
                        // VisualEffectBlur removed, so replace with a fallback background color
                        Color.black.opacity(0.5)
                        
                        HStack(spacing: 12) {
                            // Small app icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(Color(UIColor.systemGray5))
                                    .frame(width: 40, height: 40)
                                
                                if let iconImage = iconImage {
                                    Image(uiImage: iconImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 9))
                                        .opacity(showIcon ? 1 : 0)
                                        .scaleEffect(showIcon ? 1 : 0.8)
                                        .animation(.easeOut(duration: 0.3), value: showIcon)
                                } else {
                                    Image(systemName: "app.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(UIColor.systemGray3))
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text(app.category.name)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(UIColor.systemGray))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Add/Added Button
                            Button(action: {
                                guard !isAdded else { return }
                                Task {
                                    isAdding = true
                                    await onAdd()
                                    isAdding = false
                                }
                            }) {
                                if isAdding {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.0, green: 0.478, blue: 1.0)))
                                        .scaleEffect(0.8)
                                        .frame(width: 75, height: 30)
                                } else {
                                    Text(isAdded ? "Added" : "Add")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(
                                            isAdded 
                                                ? Color(UIColor.systemGray2) 
                                                : Color(red: 0.0, green: 0.478, blue: 1.0)
                                        )
                                        .frame(width: 75, height: 30)
                                        .background(Color(UIColor.systemGray5))
                                        .cornerRadius(15)
                                }
                            }
                            .disabled(isAdding || isAdded)
                            .animation(.easeInOut(duration: 0.2), value: isAdded)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .frame(height: 72)
                }
            }
        }
        .frame(height: 450)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .onAppear {
            loadBackgroundImage()
            loadIcon()
        }
    }
    
    private func loadBackgroundImage() {
        // Try to load first screenshot or icon as background
        let imageUrl = app.screenshots.first ?? app.iconUrl
        guard let urlString = imageUrl,
              let url = URL(string: urlString) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.backgroundImage = image
                    }
                }
            } catch {
                print("Failed to load background image: \(error)")
            }
        }
    }
    
    private func loadIcon() {
        guard let iconUrl = app.iconUrl,
              let url = URL(string: iconUrl) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.iconImage = image
                        withAnimation(.easeOut(duration: 0.3)) {
                            self.showIcon = true
                        }
                    }
                }
            } catch {
                print("Failed to load icon: \(error)")
            }
        }
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let name: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                // Only show icon if it's not "All" or if it's an emoji
                if name != "All" {
                    if icon.count > 1 {
                        // Emoji icon
                        Text(icon)
                            .font(.system(size: 16))
                    } else {
                        // SF Symbol
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isSelected ? .black : .white)
                    }
                }
                
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSelected ? .black : .white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white : Color.gray.opacity(0.2))
            )
            .overlay(
                Capsule()
                    .stroke(Color.gray.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
    }
}

// MARK: - Preview Helpers

struct AppStoreComponents_Previews: PreviewProvider {
    static let sampleApp = AppStoreApp(
        id: "1",
        name: "Uniswap",
        url: "https://app.uniswap.org",
        iconUrl: "https://app.uniswap.org/favicon.ico",
        category: AppStoreCategory(
            id: "defi",
            name: "DeFi",
            slug: "defi",
            description: "Decentralized Finance",
            icon: "💰",
            position: 1,
            appsCount: nil,
            createdAt: "2024-01-01",
            updatedAt: "2024-01-01"
        ),
        description: "Trade crypto on the leading DEX",
        detailedDescription: nil,
        tags: ["swap", "dex"],
        popularity: 100,
        isNew: true,
        isFeatured: true,
        chainSupport: ["1", "137"],
        screenshots: [],
        developer: "Uniswap Labs",
        version: "4.0",
        lastUpdated: "2024-01-01",
        shareableId: nil,
        metadata: nil,
        createdAt: "2024-01-01",
        updatedAt: "2024-01-01"
    )
    
    static var previews: some View {
        VStack {
            AppStoreRowView(app: sampleApp, isAdded: false) { }
                .padding()
            
            FeaturedAppCard(app: sampleApp, isAdded: false) { }
                .padding()
            
            HStack {
                CategoryPill(name: "All", icon: "square.grid.2x2", isSelected: true) { }
                CategoryPill(name: "DeFi", icon: "💰", isSelected: false) { }
            }
            .padding()
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}

