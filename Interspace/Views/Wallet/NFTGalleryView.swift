import SwiftUI

struct NFTGalleryView: View {
    @State private var selectedCollection: NFTCollection?
    @State private var selectedNFT: NFT?
    @State private var showAllNFTs = false
    @State private var galleryLayout: GalleryLayout = .grid
    @Environment(\.colorScheme) var colorScheme
    
    // Mock data - replace with real data from API
    let collections: [NFTCollection] = NFTCollection.mockCollections
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                Text("NFTs")
                    .font(WalletDesign.Typography.sectionHeader)
                    .foregroundColor(.primary)
                
                if !collections.isEmpty {
                    Text("\(totalNFTCount)")
                        .font(WalletDesign.Typography.chainLabel)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                Button(action: { showAllNFTs = true }) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(WalletDesign.Typography.tokenValue)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(WalletDesign.Colors.actionPrimary)
                }
            }
            .padding(.horizontal, WalletDesign.Spacing.regular)
            .padding(.top, WalletDesign.Spacing.section)
            .padding(.bottom, WalletDesign.Spacing.regular)
            
            if collections.isEmpty {
                EmptyNFTState()
            } else {
                // Featured Collection
                if let featured = collections.first {
                    FeaturedCollectionCard(collection: featured)
                        .padding(.horizontal, WalletDesign.Spacing.regular)
                        .padding(.bottom, WalletDesign.Spacing.regular)
                }
                
                // Other Collections
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WalletDesign.Spacing.regular) {
                        ForEach(collections.dropFirst().prefix(5)) { collection in
                            CollectionCard(collection: collection)
                                .onTapGesture {
                                    selectedCollection = collection
                                    HapticManager.impact(.light)
                                }
                        }
                    }
                    .padding(.horizontal, WalletDesign.Spacing.regular)
                }
            }
        }
        .sheet(isPresented: $showAllNFTs) {
            NFTFullGalleryView(collections: collections)
        }
        .sheet(item: $selectedCollection) { collection in
            CollectionDetailView(collection: collection)
        }
        .sheet(item: $selectedNFT) { nft in
            NFTDetailView(nft: nft)
        }
    }
    
    private var totalNFTCount: Int {
        collections.reduce(0) { $0 + $1.nfts.count }
    }
}

// MARK: - Featured Collection Card
struct FeaturedCollectionCard: View {
    let collection: NFTCollection
    @State private var currentIndex = 0
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: WalletDesign.Spacing.tight) {
            // Collection Header
            HStack {
                Text(collection.name)
                    .font(WalletDesign.Typography.tokenName)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(collection.nfts.count) items")
                    .font(WalletDesign.Typography.chainLabel)
                    .foregroundColor(.secondary)
            }
            
            // NFT Carousel
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(Array(collection.nfts.prefix(3).enumerated()), id: \.element.id) { index, nft in
                        NFTFeaturedCard(nft: nft)
                            .frame(width: geometry.size.width)
                            .scaleEffect(currentIndex == index ? 1 : 0.9)
                            .opacity(currentIndex == index ? 1 : 0.7)
                            .animation(WalletDesign.Animation.spring, value: currentIndex)
                    }
                }
                .offset(x: -CGFloat(currentIndex) * geometry.size.width + dragOffset.width)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            let threshold = geometry.size.width * 0.3
                            
                            withAnimation(WalletDesign.Animation.spring) {
                                if value.translation.width > threshold && currentIndex > 0 {
                                    currentIndex -= 1
                                } else if value.translation.width < -threshold && currentIndex < min(2, collection.nfts.count - 1) {
                                    currentIndex += 1
                                }
                                dragOffset = .zero
                            }
                            
                            HapticManager.impact(.light)
                        }
                )
            }
            .frame(height: 200)
            
            // Page Indicator
            HStack(spacing: 6) {
                ForEach(0..<min(3, collection.nfts.count), id: \.self) { index in
                    Circle()
                        .fill(currentIndex == index ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .animation(WalletDesign.Animation.spring, value: currentIndex)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(WalletDesign.Spacing.regular)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - NFT Featured Card
struct NFTFeaturedCard: View {
    let nft: NFT
    @State private var imageLoaded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: WalletDesign.Spacing.tight) {
            // NFT Image
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(UIColor.systemGray5),
                                Color(UIColor.systemGray4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                if !imageLoaded {
                    Image(systemName: WalletSymbols.nft)
                        .font(.system(size: 40))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
                
                // Rarity Badge
                if let rarity = nft.rarity {
                    VStack {
                        HStack {
                            Spacer()
                            RarityBadge(rarity: rarity)
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            
            // NFT Info
            VStack(alignment: .leading, spacing: 2) {
                Text(nft.name)
                    .font(WalletDesign.Typography.tokenName)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack {
                    Text("#\(nft.tokenId)")
                        .font(WalletDesign.Typography.caption)
                        .foregroundColor(.secondary)
                    
                    if let price = nft.floorPrice {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(price)
                            .font(WalletDesign.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Collection Card
struct CollectionCard: View {
    let collection: NFTCollection
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: WalletDesign.Spacing.tight) {
            // Collection Preview Grid
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .frame(width: 140, height: 140)
                
                LazyVGrid(columns: [GridItem(.fixed(65)), GridItem(.fixed(65))], spacing: 4) {
                    ForEach(collection.nfts.prefix(4)) { nft in
                        NFTThumbnail(nft: nft)
                    }
                }
                .padding(6)
            }
            
            // Collection Info
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(WalletDesign.Typography.tokenName)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(collection.nfts.count) items")
                    .font(WalletDesign.Typography.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 140, alignment: .leading)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(WalletDesign.Animation.easeOut, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - NFT Thumbnail
struct NFTThumbnail: View {
    let nft: NFT
    
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(
                LinearGradient(
                    colors: generateGradientColors(from: nft.id),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "photo.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            )
    }
    
    private func generateGradientColors(from string: String) -> [Color] {
        let hash = string.hashValue
        let hue1 = Double(abs(hash % 360)) / 360.0
        let hue2 = (hue1 + 0.2).truncatingRemainder(dividingBy: 1.0)
        
        return [
            Color(hue: hue1, saturation: 0.4, brightness: 0.9),
            Color(hue: hue2, saturation: 0.5, brightness: 0.8)
        ]
    }
}

// MARK: - Rarity Badge
struct RarityBadge: View {
    let rarity: NFTRarity
    
    var body: some View {
        Text(rarity.displayName)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(rarity.color)
            )
    }
}

// MARK: - Empty NFT State
struct EmptyNFTState: View {
    var body: some View {
        VStack(spacing: WalletDesign.Spacing.regular) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.secondary)
            
            VStack(spacing: WalletDesign.Spacing.tight) {
                Text("No NFTs Yet")
                    .font(WalletDesign.Typography.tokenName)
                    .foregroundColor(.primary)
                
                Text("Your NFT collection will appear here")
                    .font(WalletDesign.Typography.chainLabel)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, WalletDesign.Spacing.section)
        .padding(.horizontal, WalletDesign.Spacing.regular)
    }
}

// MARK: - Full Gallery View
struct NFTFullGalleryView: View {
    let collections: [NFTCollection]
    @State private var selectedTab = 0
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selection
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WalletDesign.Spacing.regular) {
                        TabButton(title: "All", isSelected: selectedTab == 0) {
                            selectedTab = 0
                        }
                        
                        ForEach(Array(collections.enumerated()), id: \.element.id) { index, collection in
                            TabButton(title: collection.name, isSelected: selectedTab == index + 1) {
                                selectedTab = index + 1
                            }
                        }
                    }
                    .padding(.horizontal, WalletDesign.Spacing.regular)
                }
                .padding(.vertical, WalletDesign.Spacing.tight)
                
                // Gallery Grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: WalletDesign.Spacing.regular) {
                        ForEach(filteredNFTs) { nft in
                            NFTGridCard(nft: nft)
                        }
                    }
                    .padding(WalletDesign.Spacing.regular)
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("NFT Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "square.grid.2x2")
                    }
                }
            }
        }
    }
    
    private var filteredNFTs: [NFT] {
        let nfts: [NFT]
        if selectedTab == 0 {
            nfts = collections.flatMap { $0.nfts }
        } else {
            nfts = collections[selectedTab - 1].nfts
        }
        
        if searchText.isEmpty {
            return nfts
        }
        
        return nfts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(WalletDesign.Typography.tokenValue)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, WalletDesign.Spacing.regular)
                .padding(.vertical, WalletDesign.Spacing.tight)
                .background(
                    Capsule()
                        .fill(isSelected ? WalletDesign.Colors.actionPrimary : Color(UIColor.tertiarySystemBackground))
                )
        }
    }
}

// MARK: - NFT Grid Card
struct NFTGridCard: View {
    let nft: NFT
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: WalletDesign.Spacing.tight) {
            // NFT Image
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: generateGradientColors(from: nft.id),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(1, contentMode: .fit)
                
                Image(systemName: "photo.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            // NFT Info
            VStack(alignment: .leading, spacing: 2) {
                Text(nft.name)
                    .font(WalletDesign.Typography.tokenName)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("#\(nft.tokenId)")
                    .font(WalletDesign.Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(WalletDesign.Animation.easeOut, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    private func generateGradientColors(from string: String) -> [Color] {
        let hash = string.hashValue
        let hue = Double(abs(hash % 360)) / 360.0
        
        return [
            Color(hue: hue, saturation: 0.5, brightness: 0.9),
            Color(hue: (hue + 0.1).truncatingRemainder(dividingBy: 1.0), saturation: 0.6, brightness: 0.8)
        ]
    }
}

// MARK: - Models
struct NFTCollection: Identifiable {
    let id = UUID().uuidString
    let name: String
    let nfts: [NFT]
    let floorPrice: String?
    let totalValue: String?
    
    static let mockCollections: [NFTCollection] = [
        NFTCollection(
            name: "Bored Apes",
            nfts: NFT.mockNFTs(count: 8, collection: "Bored Apes"),
            floorPrice: "32.5 ETH",
            totalValue: "$125,000"
        ),
        NFTCollection(
            name: "Pudgy Penguins",
            nfts: NFT.mockNFTs(count: 5, collection: "Pudgy Penguins"),
            floorPrice: "5.2 ETH",
            totalValue: "$15,000"
        ),
        NFTCollection(
            name: "Art Blocks",
            nfts: NFT.mockNFTs(count: 3, collection: "Art Blocks"),
            floorPrice: "2.8 ETH",
            totalValue: "$8,500"
        )
    ]
}

struct NFT: Identifiable {
    let id = UUID().uuidString
    let name: String
    let tokenId: String
    let collection: String
    let imageUrl: String?
    let rarity: NFTRarity?
    let floorPrice: String?
    
    static func mockNFTs(count: Int, collection: String) -> [NFT] {
        (0..<count).map { index in
            NFT(
                name: "\(collection) #\(1000 + index)",
                tokenId: "\(1000 + index)",
                collection: collection,
                imageUrl: nil,
                rarity: NFTRarity.allCases.randomElement(),
                floorPrice: index % 3 == 0 ? "\(Double.random(in: 1...10).rounded(to: 1)) ETH" : nil
            )
        }
    }
}

enum NFTRarity: CaseIterable {
    case common, uncommon, rare, epic, legendary
    
    var displayName: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }
    
    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

enum GalleryLayout {
    case grid, list
}

// MARK: - Detail Views Placeholders
struct CollectionDetailView: View {
    let collection: NFTCollection
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("Collection Detail - \(collection.name)")
                .navigationTitle(collection.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct NFTDetailView: View {
    let nft: NFT
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("NFT Detail - \(nft.name)")
                .navigationTitle(nft.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - Helper Extensions
extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}