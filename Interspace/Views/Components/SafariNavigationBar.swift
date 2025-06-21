import SwiftUI
import UIKit

// MARK: - Safari Navigation Bar
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
            // Show page title if available, otherwise show domain
            if !webPage.title.isEmpty && webPage.title != url.absoluteString {
                return webPage.title
            }
            return url.host ?? url.absoluteString
        }
        return searchText.isEmpty ? "Search or enter website name" : searchText
    }
    
    private var isSecure: Bool {
        webPage.url?.scheme == "https"
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Back Button
            SafariButton(
                icon: "chevron.left",
                isEnabled: webPage.canGoBack,
                action: { webPage.goBack() }
            )
            .frame(width: 44)
            
            // Forward Button
            SafariButton(
                icon: "chevron.right",
                isEnabled: webPage.canGoForward,
                action: { webPage.goForward() }
            )
            .frame(width: 44)
            
            Spacer(minLength: 12)
            
            // URL/Search Field
            Button(action: {
                HapticManager.impact(.light)
                searchText = webPage.url?.absoluteString ?? ""
                onShowSearch()
            }) {
                HStack(spacing: 6) {
                    if webPage.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.white.opacity(0.6)))
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                    } else if isSecure {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    
                    Text(displayText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    if webPage.isLoading {
                        Spacer(minLength: 14)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
                )
            }
            .scaleEffect(urlFieldScale)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.15, dampingFraction: 0.9)) {
                    urlFieldScale = pressing ? 0.98 : 1.0
                }
            }, perform: {})
            
            Spacer(minLength: 12)
            
            // Share Button
            SafariButton(
                icon: "square.and.arrow.up",
                isEnabled: webPage.url != nil,
                action: onShare
            )
            .frame(width: 44)
            
            // Menu Button
            Menu {
                Button(action: onAddApp) {
                    Label("Add to Apps", systemImage: "plus.square.on.square")
                }
                
                if let onAddToProfile = onAddToProfile {
                    Button(action: onAddToProfile) {
                        Label("Add to Profile...", systemImage: "person.crop.circle.badge.plus")
                    }
                }
                
                Button(action: {
                    if let url = webPage.url {
                        UIPasteboard.general.string = url.absoluteString
                        HapticManager.notification(.success)
                    }
                }) {
                    Label("Copy Link", systemImage: "doc.on.doc")
                }
                
                Button(action: {
                    if let url = webPage.url {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label("Open in Safari", systemImage: "safari")
                }
                
                Divider()
                
                Button(action: {
                    webPage.reload()
                }) {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SafariButtonStyle())
            
            // Tab Switcher Button
            Button(action: onDismiss) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    
                    Text("1")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(SafariButtonStyle())
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .padding(.vertical, 8)
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
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(isEnabled ? .white : Color.white.opacity(0.3))
                .frame(width: 44, height: 44)
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
            // Base blur layer
            SafariVisualEffectView(material: .systemChromeMaterial, blurStyle: .systemChromeMaterialDark)
            
            // Additional tint overlay
            Color.black.opacity(0.2)
            
            // Subtle inner glow
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
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
        "apple.com",
        "github.com",
        "interspace.fi"
    ]
    
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isVisible = false
                    }
                }
            
            VStack(spacing: 0) {
                // Search Field Container
                VStack(spacing: 16) {
                    // Search Field
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17))
                            .foregroundColor(Color.white.opacity(0.5))
                        
                        TextField("Search or enter website name", text: $searchText)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .focused($isSearchFocused)
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
                                    .font(.system(size: 17))
                                    .foregroundColor(Color.white.opacity(0.3))
                            }
                        }
                        
                        Button("Cancel") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                isVisible = false
                            }
                        }
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                    )
                    
                    // Suggestions
                    VStack(alignment: .leading, spacing: 0) {
                        if searchText.isEmpty {
                            Text("Recent")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.5))
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            
                            ForEach(recentSearches, id: \.self) { search in
                                Button(action: {
                                    onSelectURL(search)
                                }) {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color.white.opacity(0.3))
                                        
                                        Text(search)
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.05))
                                }
                            }
                        } else {
                            // Search suggestions based on input
                            ForEach(searchSuggestions, id: \.self) { suggestion in
                                Button(action: {
                                    onSelectURL(suggestion)
                                }) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color.white.opacity(0.3))
                                        
                                        Text(suggestion)
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.05))
                                }
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                            .background(
                                SafariVisualEffectView(material: .systemChromeMaterial, blurStyle: .systemChromeMaterialDark)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            )
                    )
                }
                .padding(16)
                
                Spacer()
            }
            .padding(.top, 100)
        }
        .onAppear {
            isSearchFocused = true
        }
    }
    
    private var searchSuggestions: [String] {
        guard !searchText.isEmpty else { return [] }
        
        // Basic suggestions
        if searchText.contains(".") {
            return [searchText]
        } else {
            return [
                "\(searchText).com",
                "\(searchText).org",
                "\(searchText).io",
                "Search Google for '\(searchText)'"
            ]
        }
    }
}