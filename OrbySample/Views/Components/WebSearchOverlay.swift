import SwiftUI

// MARK: - Web Search Overlay
struct WebSearchOverlay: View {
    @Binding var searchText: String
    @Binding var isVisible: Bool
    let onSelectURL: (String) -> Void
    
    @State private var recentSearches: [String] = []
    @State private var suggestions: [SearchSuggestion] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Tap to dismiss area
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isVisible = false
                    }
                }
            
            // Search content
            VStack(spacing: 0) {
                // Search suggestions
                ScrollView {
                    VStack(spacing: 0) {
                        if !searchText.isEmpty {
                            // URL suggestions
                            if searchText.contains(".") || searchText.hasPrefix("http") {
                                SearchSuggestionRow(
                                    icon: "globe",
                                    title: searchText,
                                    subtitle: "Go to website",
                                    onTap: {
                                        onSelectURL(searchText)
                                    }
                                )
                            }
                            
                            // Search suggestion
                            SearchSuggestionRow(
                                icon: "magnifyingglass",
                                title: searchText,
                                subtitle: "Search Google",
                                onTap: {
                                    onSelectURL(searchText)
                                }
                            )
                            
                            Divider()
                                .background(DesignTokens.Colors.borderSecondary)
                                .padding(.vertical, 8)
                        }
                        
                        // Recent searches
                        if recentSearches.isEmpty {
                            // Default suggestions
                            ForEach(defaultSuggestions) { suggestion in
                                SearchSuggestionRow(
                                    icon: suggestion.icon,
                                    title: suggestion.title,
                                    subtitle: suggestion.subtitle,
                                    onTap: {
                                        onSelectURL(suggestion.url)
                                    }
                                )
                            }
                        } else {
                            // Recent searches header
                            HStack {
                                Text("Recent Searches")
                                    .font(DesignTokens.Typography.labelMedium)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                
                                Spacer()
                                
                                Button("Clear All") {
                                    recentSearches.removeAll()
                                }
                                .font(DesignTokens.Typography.labelSmall)
                                .foregroundColor(DesignTokens.Colors.primary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            
                            ForEach(recentSearches, id: \.self) { search in
                                SearchSuggestionRow(
                                    icon: "clock.arrow.circlepath",
                                    title: search,
                                    subtitle: nil,
                                    onTap: {
                                        onSelectURL(search)
                                    }
                                )
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
            .background(
                VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                    .overlay(Color.black.opacity(0.2))
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
        }
        .onAppear {
            loadRecentSearches()
        }
    }
    
    private func loadRecentSearches() {
        // Load from UserDefaults or cache
        // For now, using mock data
        recentSearches = [
            "uniswap",
            "opensea",
            "ethereum price",
            "defi protocols"
        ]
    }
    
    private var defaultSuggestions: [SearchSuggestion] {
        [
            SearchSuggestion(
                icon: "globe",
                title: "guardian",
                subtitle: "theguardian.com",
                url: "https://theguardian.com"
            ),
            SearchSuggestion(
                icon: "globe",
                title: "forbes",
                subtitle: "forbes.com",
                url: "https://forbes.com"
            )
        ]
    }
}

// MARK: - Search Suggestion Row
struct SearchSuggestionRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.selection()
            onTap()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .background(
                isPressed ? DesignTokens.Colors.fillTertiary : Color.clear
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Search Suggestion Model
struct SearchSuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let url: String
}