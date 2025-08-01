import SwiftUI
import UIKit

// MARK: - Safari Navigation Bar
@available(iOS 15.0, *)
struct SafariNavigationBar: View {
    @ObservedObject var webPage: WebPage
    @Binding var searchText: String
    let onDismiss: () -> Void
    let onShare: () -> Void
    let onAddApp: () -> Void
    let onShowSearch: () -> Void
    var onAddToProfile: (() -> Void)? = nil
    
    @State private var urlFieldScale: CGFloat = 1.0
    @State private var isPressed = false
    
    private var displayText: String {
        if let url = webPage.url {
            // Show domain for cleaner look
            return url.host ?? url.absoluteString
        }
        return "Search or enter website name"
    }
    
    private var isSecure: Bool {
        webPage.url?.scheme == "https"
    }
    
    var body: some View {
        // Simplified layout matching iOS Safari
        HStack(spacing: 16) {
            // Back/Forward buttons group
            HStack(spacing: 20) {
                SafariButton(
                    icon: "chevron.left",
                    isEnabled: webPage.canGoBack,
                    action: { webPage.goBack() }
                )
                
                SafariButton(
                    icon: "chevron.right",
                    isEnabled: webPage.canGoForward,
                    action: { webPage.goForward() }
                )
            }
            
            // Compact URL Field
            Button(action: {
                HapticManager.impact(.light)
                onShowSearch()
            }) {
                HStack(spacing: 6) {
                    if isSecure {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    
                    Text(displayText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.5))
                        .opacity(webPage.isLoading ? 1 : 0)
                        .rotationEffect(.degrees(webPage.isLoading ? 360 : 0))
                        .animation(webPage.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: webPage.isLoading)
                }
                .padding(.horizontal, 14)
                .frame(height: 32)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                )
            }
            .scaleEffect(urlFieldScale)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.15, dampingFraction: 0.9)) {
                    urlFieldScale = pressing ? 0.96 : 1.0
                }
            }, perform: {})
            
            // Action buttons group
            HStack(spacing: 20) {
                // Share Button
                SafariButton(
                    icon: "square.and.arrow.up",
                    isEnabled: webPage.url != nil,
                    action: onShare
                )
                
                // Quick Add Button
                SafariButton(
                    icon: "plus.app",
                    isEnabled: webPage.url != nil,
                    action: onAddApp
                )
                
                // Tab Grid Button
                Button(action: onDismiss) {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SafariButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .padding(.vertical, 4)
        .background(
            SafariNavigationBackground()
        )
    }
}

// MARK: - Safari Button
struct SafariButton: View {
    let icon: String
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            if isEnabled {
                HapticManager.impact(.light)
                action()
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(isEnabled ? .white : Color.white.opacity(0.3))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
        .buttonStyle(SafariButtonStyle())
    }
}

// MARK: - Safari Button Style
struct SafariButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

// MARK: - Safari Navigation Background
struct SafariNavigationBackground: View {
    var body: some View {
        ZStack {
            // Minimal blur effect
            SafariVisualEffectView(material: .systemUltraThinMaterial, blurStyle: .systemUltraThinMaterialDark)
            
            // Very subtle tint
            Color.black.opacity(0.1)
        }
        .overlay(
            // Top border only
            VStack(spacing: 0) {
                Color.white.opacity(0.1)
                    .frame(height: 0.5)
                Spacer()
            }
        )
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Safari Visual Effect View
struct SafariVisualEffectView: UIViewRepresentable {
    let material: UIBlurEffect.Style
    let blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

// MARK: - Safari Search Overlay
struct SafariSearchOverlay: View {
    @Binding var searchText: String
    @Binding var isVisible: Bool
    let onSelectURL: (String) -> Void
    
    @State private var recentSearches: [String] = [
        "uniswap.org",
        "ethereum.org",
        "opensea.io"
    ]
    
    @State private var overlayOpacity: Double = 0
    @State private var contentOffset: CGFloat = 50
    
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        ZStack {
            // Full screen blur backdrop
            SafariVisualEffectView(material: .systemUltraThinMaterial, blurStyle: .systemUltraThinMaterialDark)
                .ignoresSafeArea()
                .opacity(overlayOpacity)
                .onTapGesture {
                    dismissSearch()
                }
            
            VStack(spacing: 0) {
                // Compact Search Container
                VStack(spacing: 0) {
                    // Search Bar
                    HStack(spacing: 12) {
                        // Search Field
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.5))
                            
                            TextField("Search or enter website name", text: $searchText)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .focused($isSearchFocused)
                                .submitLabel(.go)
                                .onSubmit {
                                    if !searchText.isEmpty {
                                        onSelectURL(searchText)
                                    }
                                }
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.15))
                        )
                        
                        // Cancel Button
                        Button("Cancel") {
                            dismissSearch()
                        }
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 60)
                    .padding(.bottom, 20)
                    
                    // Suggestions List
                    ScrollView {
                        VStack(spacing: 0) {
                            if searchText.isEmpty {
                                // Recent searches
                                HStack {
                                    Text("Recent Searches")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.white.opacity(0.5))
                                        .textCase(.uppercase)
                                    
                                    Spacer()
                                    
                                    Button("Clear") {
                                        recentSearches.removeAll()
                                    }
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.5))
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)
                                
                                ForEach(recentSearches, id: \.self) { search in
                                    SearchResultRow(
                                        icon: "clock.arrow.circlepath",
                                        text: search,
                                        action: {
                                            onSelectURL(search)
                                        }
                                    )
                                }
                            } else {
                                // Search suggestions
                                ForEach(searchSuggestions, id: \.self) { suggestion in
                                    SearchResultRow(
                                        icon: suggestion.contains("Search") ? "globe" : "magnifyingglass",
                                        text: suggestion,
                                        action: {
                                            onSelectURL(suggestion)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxHeight: 400)
                }
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black.opacity(0.3))
                        .background(
                            SafariVisualEffectView(material: .systemChromeMaterial, blurStyle: .systemChromeMaterialDark)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        )
                )
                .offset(y: contentOffset)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                overlayOpacity = 1
                contentOffset = 0
            }
            
            // Focus search field after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isSearchFocused = true
            }
        }
    }
    
    private func dismissSearch() {
        isSearchFocused = false
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            overlayOpacity = 0
            contentOffset = 50
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isVisible = false
        }
    }
    
    private var searchSuggestions: [String] {
        guard !searchText.isEmpty else { return [] }
        
        // Smart suggestions
        var suggestions: [String] = []
        
        // Check if it's already a URL
        if searchText.contains(".") {
            suggestions.append(searchText)
        } else {
            // Common Web3 domains
            suggestions.append("\(searchText).com")
            suggestions.append("\(searchText).app")
            suggestions.append("\(searchText).xyz")
        }
        
        // Always add search option
        suggestions.append("Search for '\(searchText)'")
        
        return suggestions
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let icon: String
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color.white.opacity(0.5))
                    .frame(width: 24)
                
                Text(text)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.white.opacity(0.001))
    }
}