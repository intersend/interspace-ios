import SwiftUI

// MARK: - Web Navigation Bar
struct WebNavigationBar: View {
    @ObservedObject var webPage: WebPage
    let app: BookmarkedApp
    @Binding var searchText: String
    @Binding var isSearchFieldFocused: Bool
    @Binding var showSearchSuggestions: Bool
    let onDismiss: () -> Void
    let onAddApp: () -> Void
    let onAddToProfile: () -> Void
    
    @State private var isExpanded = false
    @State private var showMenu = false
    @State private var addButtonScale: CGFloat = 1.0
    @State private var menuButtonScale: CGFloat = 1.0
    
    private var displayURL: String {
        if let url = webPage.url {
            return url.host ?? url.absoluteString
        }
        return app.url
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                // Expanded Mode - Top Controls
                HStack(spacing: 16) {
                    // Back button
                    NavigationButton(
                        icon: "chevron.left",
                        isEnabled: webPage.canGoBack,
                        action: { webPage.goBack() }
                    )
                    
                    // Forward button
                    NavigationButton(
                        icon: "chevron.right",
                        isEnabled: webPage.canGoForward,
                        action: { webPage.goForward() }
                    )
                    
                    Spacer()
                    
                    // Reload/Stop button
                    NavigationButton(
                        icon: webPage.isLoading ? "xmark" : "arrow.clockwise",
                        isEnabled: true,
                        action: {
                            if webPage.isLoading {
                                webPage.stopLoading()
                            } else {
                                webPage.reload()
                            }
                        }
                    )
                    
                    // Share button
                    NavigationButton(
                        icon: "square.and.arrow.up",
                        isEnabled: true,
                        action: {
                            shareCurrentPage()
                        }
                    )
                    
                    // Bookmark button
                    NavigationButton(
                        icon: "bookmark",
                        isEnabled: true,
                        action: {
                            onAddApp()
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                // Search Field
                SearchField(
                    searchText: $searchText,
                    isSearchFieldFocused: $isSearchFieldFocused,
                    showSearchSuggestions: $showSearchSuggestions,
                    currentURL: displayURL,
                    onSubmit: { /* Handled by parent */ }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
            } else {
                // Compact Mode
                HStack(spacing: 12) {
                    // Back button
                    NavigationButton(
                        icon: "chevron.left",
                        isEnabled: webPage.canGoBack,
                        action: { webPage.goBack() }
                    )
                    .frame(width: 36, height: 36)
                    
                    // Menu button
                    Menu {
                        menuContent
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(DesignTokens.GlassEffect.ultraThin)
                            )
                            .scaleEffect(menuButtonScale)
                    }
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded { _ in
                                HapticManager.impact(.light)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    menuButtonScale = 0.92
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        menuButtonScale = 1.0
                                    }
                                }
                            }
                    )
                    
                    // URL Field (Tap to expand)
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded = true
                            isSearchFieldFocused = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            if webPage.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                    .opacity(displayURL.hasPrefix("https") ? 1 : 0)
                            }
                            
                            Text(displayURL)
                                .font(DesignTokens.Typography.bodySmall)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(DesignTokens.GlassEffect.ultraThin)
                        )
                    }
                    
                    // Add button
                    Button(action: {
                        HapticManager.impact(.medium)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            addButtonScale = 0.92
                        }
                        onAddApp()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                addButtonScale = 1.0
                            }
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(DesignTokens.GlassEffect.ultraThin)
                            )
                    }
                    .scaleEffect(addButtonScale)
                    
                    // Tab switcher button
                    Button(action: {
                        // Tab switcher would go here
                        onDismiss()
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(DesignTokens.Colors.textPrimary, lineWidth: 1.5)
                                .frame(width: 18, height: 18)
                            
                            Text("1")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                        }
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(DesignTokens.GlassEffect.ultraThin)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .background(
            VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                .overlay(
                    Color.black.opacity(0.1)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: isExpanded ? 20 : 0, style: .continuous)
                )
        )
        .padding(.horizontal, isExpanded ? 16 : 0)
        .padding(.bottom, isExpanded ? 8 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }
    
    @ViewBuilder
    private var menuContent: some View {
        Group {
            Button(action: {
                shareCurrentPage()
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Button(action: {
                onAddApp()
            }) {
                Label("Add to Apps", systemImage: "plus.app")
            }
            
            Button(action: {
                onAddToProfile()
            }) {
                Label("Add to Profile...", systemImage: "person.crop.circle.badge.plus")
            }
            
            Divider()
            
            Button(action: {
                copyCurrentURL()
            }) {
                Label("Copy Link", systemImage: "doc.on.doc")
            }
            
            Button(action: {
                openInSafari()
            }) {
                Label("Open in Safari", systemImage: "safari")
            }
            
            Divider()
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                Label("Show Controls", systemImage: "slider.horizontal.3")
            }
        }
    }
    
    private func shareCurrentPage() {
        guard let url = webPage.url else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func copyCurrentURL() {
        if let url = webPage.url {
            UIPasteboard.general.string = url.absoluteString
            HapticManager.notification(.success)
        }
    }
    
    private func openInSafari() {
        if let url = webPage.url {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Navigation Button
struct NavigationButton: View {
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
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isEnabled ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textTertiary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(DesignTokens.GlassEffect.ultraThin)
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .disabled(!isEnabled)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Search Field
struct SearchField: View {
    @Binding var searchText: String
    @Binding var isSearchFieldFocused: Bool
    @Binding var showSearchSuggestions: Bool
    let currentURL: String
    let onSubmit: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(DesignTokens.Colors.textSecondary)
            
            TextField("Search or enter website name", text: $searchText)
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .accentColor(DesignTokens.Colors.primary)
                .focused($isFocused)
                .onSubmit {
                    onSubmit()
                }
                .onChange(of: isFocused) { oldValue, newValue in
                    isSearchFieldFocused = newValue
                    if newValue {
                        searchText = currentURL
                        showSearchSuggestions = true
                    } else {
                        showSearchSuggestions = false
                    }
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.GlassEffect.thin)
        )
    }
}

// MARK: - Visual Effect Blur
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}