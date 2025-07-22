import SwiftUI

struct NFTGalleryView: View {
    let nfts: [NFTItem]
    let isLoading: Bool
    
    @State private var selectedNFT: NFTItem?
    @State private var showAllNFTs = false
    @Environment(\.colorScheme) var colorScheme
    
    private var collections: [NFTCollection] {
        nfts.groupedByCollection()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                NFTSkeletonView(itemCount: 4)
                    .padding(.top, WalletDesign.Spacing.section)
            } else if !nfts.isEmpty {
                // Section Header
                NFTSectionHeader(
                    totalCount: nfts.count,
                    onSeeAll: { showAllNFTs = true }
                )
                .padding(.top, WalletDesign.Spacing.section)
                .padding(.bottom, WalletDesign.Spacing.regular)
                
                // NFT Content
                if collections.count > 1 {
                    // Multiple collections - show collection rows
                    VStack(spacing: WalletDesign.Spacing.section) {
                        ForEach(collections.prefix(3)) { collection in
                            NFTCollectionRow(collection: collection) { nft in
                                selectedNFT = nft
                            }
                        }
                    }
                } else {
                    // Single collection or mixed - show grid
                    NFTGridPreview(
                        nfts: Array(nfts.prefix(6)),
                        onItemTap: { selectedNFT = $0 }
                    )
                    .padding(.horizontal, WalletDesign.Spacing.regular)
                }
            }
        }
        .sheet(isPresented: $showAllNFTs) {
            NFTFullGalleryView(nfts: nfts, collections: collections)
        }
        .sheet(item: $selectedNFT) { nft in
            NFTDetailView(nft: nft)
        }
    }
}

// MARK: - Section Header
struct NFTSectionHeader: View {
    let totalCount: Int
    let onSeeAll: () -> Void
    
    var body: some View {
        HStack {
            Text("NFTs")
                .font(WalletDesign.Typography.sectionHeader)
                .foregroundColor(.primary)
            
            if totalCount > 0 {
                Text("\(totalCount)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            Button(action: onSeeAll) {
                HStack(spacing: 4) {
                    Text("See All")
                        .font(.system(size: 15, weight: .medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(WalletDesign.Colors.actionPrimary)
            }
        }
        .padding(.horizontal, WalletDesign.Spacing.regular)
    }
}

// MARK: - Collection Row
struct NFTCollectionRow: View {
    let collection: NFTCollection
    let onItemTap: (NFTItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Collection Header
            HStack {
                Text(collection.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(collection.nfts.count) items")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, WalletDesign.Spacing.regular)
            
            // Horizontal scroll of NFTs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(collection.nfts.prefix(10)) { nft in
                        NFTCollectionItem(nft: nft) {
                            onItemTap(nft)
                        }
                    }
                }
                .padding(.horizontal, WalletDesign.Spacing.regular)
            }
        }
    }
}

// MARK: - Collection Item
struct NFTCollectionItem: View {
    let nft: NFTItem
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            onTap()
        }) {
            VStack(spacing: 8) {
                NFTImageView(url: nft.imageUrl, size: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
                    )
                
                Text(nft.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(WalletDesign.Animation.easeOut, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Grid Preview
struct NFTGridPreview: View {
    let nfts: [NFTItem]
    let onItemTap: (NFTItem) -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(nfts) { nft in
                NFTGridItem(nft: nft) {
                    onItemTap(nft)
                }
            }
        }
    }
}

// MARK: - Grid Item
struct NFTGridItem: View {
    let nft: NFTItem
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            onTap()
        }) {
            VStack(spacing: 8) {
                NFTImageView(url: nft.imageUrl, size: nil)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(nft.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("#\(nft.tokenId)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(WalletDesign.Animation.easeOut, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - NFT Image View
struct NFTImageView: View {
    let url: String?
    let size: CGFloat?
    @State private var isLoading = true
    @State private var hasError = false
    
    var body: some View {
        Group {
            if let url = url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        NFTPlaceholder()
                            .onAppear { isLoading = true }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .onAppear { isLoading = false }
                    case .failure(_):
                        NFTPlaceholder(showError: true)
                            .onAppear { hasError = true }
                    @unknown default:
                        NFTPlaceholder()
                    }
                }
            } else {
                NFTPlaceholder()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - NFT Placeholder
struct NFTPlaceholder: View {
    let showError: Bool
    
    init(showError: Bool = false) {
        self.showError = showError
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.tertiarySystemBackground)
            
            Image(systemName: showError ? "exclamationmark.triangle" : "photo")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(Color(UIColor.quaternaryLabel))
        }
    }
}

// MARK: - Full Gallery View
struct NFTFullGalleryView: View {
    let nfts: [NFTItem]
    let collections: [NFTCollection]
    
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var selectedNFT: NFTItem?
    @Environment(\.dismiss) var dismiss
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var filteredNFTs: [NFTItem] {
        if searchText.isEmpty {
            return selectedTab == 0 ? nfts : collections[selectedTab - 1].nfts
        }
        
        let searchNFTs = selectedTab == 0 ? nfts : collections[selectedTab - 1].nfts
        return searchNFTs.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Bar
                if collections.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            TabButton(title: "All", isSelected: selectedTab == 0) {
                                selectedTab = 0
                            }
                            
                            ForEach(Array(collections.enumerated()), id: \.element.id) { index, collection in
                                TabButton(
                                    title: collection.name,
                                    count: collection.nfts.count,
                                    isSelected: selectedTab == index + 1
                                ) {
                                    selectedTab = index + 1
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    
                    Divider()
                }
                
                // Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredNFTs) { nft in
                            NFTGridItem(nft: nft) {
                                selectedNFT = nft
                            }
                        }
                    }
                    .padding(16)
                }
                .searchable(text: $searchText, prompt: "Search NFTs")
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("NFT Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(item: $selectedNFT) { nft in
            NFTDetailView(nft: nft)
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void
    
    init(title: String, count: Int? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.count = count
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.selection()
            action()
        }) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    
                    if let count = count {
                        Text("\(count)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isSelected ? .primary : .secondary)
                    }
                }
                .foregroundColor(isSelected ? .primary : .secondary)
                
                Rectangle()
                    .fill(isSelected ? Color.primary : Color.clear)
                    .frame(height: 2)
                    .animation(WalletDesign.Animation.spring, value: isSelected)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - NFT Detail View (Placeholder)
struct NFTDetailView: View {
    let nft: NFTItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    NFTImageView(url: nft.imageUrl, size: nil)
                        .aspectRatio(1, contentMode: .fit)
                        .padding()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(nft.displayName)
                            .font(.system(size: 24, weight: .bold))
                        
                        if let description = nft.metadata?.description {
                            Text(description)
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        
                        if let attributes = nft.metadata?.attributes, !attributes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Properties")
                                    .font(.system(size: 17, weight: .semibold))
                                    .padding(.top)
                                
                                ForEach(attributes.indices, id: \.self) { index in
                                    if let trait = attributes[index].trait_type {
                                        HStack {
                                            Text(trait)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(attributes[index].displayValue)
                                                .fontWeight(.medium)
                                        }
                                        .font(.system(size: 15))
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("NFT Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
