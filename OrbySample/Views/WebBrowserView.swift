import SwiftUI
import WebKit

// MARK: - Web Browser View
struct WebBrowserView: View {
    let app: BookmarkedApp
    @Environment(\.dismiss) private var dismiss
    @StateObject private var webPage = WebPage()
    @State private var isNavigationBarVisible = true
    @State private var scrollOffset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0
    @State private var showProfileSelector = false
    @State private var showAddedConfirmation = false
    @State private var searchText = ""
    @State private var showSearchOverlay = false
    @State private var navigationBarOffset: CGFloat = 0
    
    // Animation states
    @State private var browserScale: CGFloat = 0.95
    @State private var browserOpacity: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Web Content
                WebView(page: webPage)
                    .ignoresSafeArea()
                    .scaleEffect(browserScale)
                    .opacity(browserOpacity)
                    .onAppear {
                        loadInitialURL()
                        animateBrowserEntry()
                    }
                    .onScrollChanged { offset in
                        handleScroll(offset)
                    }
                
                // Top Progress Bar
                VStack {
                    if webPage.isLoading {
                        WebProgressBar(progress: webPage.estimatedProgress)
                            .frame(height: 2)
                            .transition(.opacity)
                    }
                    
                    Spacer()
                }
                .ignoresSafeArea()
                
                // Bottom Navigation Bar
                VStack {
                    Spacer()
                    
                    SafariNavigationBar(
                        webPage: webPage,
                        searchText: $searchText,
                        onDismiss: { dismissBrowser() },
                        onShare: { shareCurrentPage() },
                        onAddApp: { addAppToCurrentProfile() },
                        onShowSearch: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                showSearchOverlay = true
                            }
                        },
                        onAddToProfile: { showProfileSelector = true }
                    )
                    .offset(y: navigationBarOffset)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: navigationBarOffset)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 8)
                }
                .ignoresSafeArea(.keyboard)
                
                // Search Overlay
                if showSearchOverlay {
                    SafariSearchOverlay(
                        searchText: $searchText,
                        isVisible: $showSearchOverlay,
                        onSelectURL: { url in
                            loadURL(url)
                            showSearchOverlay = false
                        }
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
        .sheet(isPresented: $showProfileSelector) {
            AddToProfileTray(
                isPresented: $showProfileSelector,
                onSelectProfile: { profile in
                    addAppToProfile(profile)
                }
            )
        }
        .overlay(
            AddedConfirmationView(isVisible: $showAddedConfirmation)
        )
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Private Methods
    
    private func loadInitialURL() {
        guard let url = URL(string: app.url) else { return }
        let request = URLRequest(url: url)
        webPage.load(request)
    }
    
    private func loadURL(_ urlString: String) {
        // Handle search vs URL
        if urlString.contains(".") || urlString.hasPrefix("http") {
            // It's likely a URL
            var finalURL = urlString
            if !finalURL.hasPrefix("http") {
                finalURL = "https://\(finalURL)"
            }
            
            if let url = URL(string: finalURL) {
                let request = URLRequest(url: url)
                webPage.load(request)
            }
        } else {
            // It's a search query
            let searchQuery = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let searchURL = URL(string: "https://www.google.com/search?q=\(searchQuery)") {
                let request = URLRequest(url: searchURL)
                webPage.load(request)
            }
        }
    }
    
    private func animateBrowserEntry() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            browserScale = 1.0
            browserOpacity = 1.0
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
    
    private func dismissBrowser() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            browserScale = 0.8
            browserOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
    
    private func handleScroll(_ offset: CGFloat) {
        let delta = offset - lastScrollOffset
        
        // Hide/show navigation bar based on scroll
        if delta > 10 && offset > 50 {
            // Scrolling down - hide navigation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                navigationBarOffset = 100
            }
        } else if delta < -5 {
            // Scrolling up - show navigation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                navigationBarOffset = 0
            }
        }
        
        lastScrollOffset = offset
    }
    
    private func addAppToCurrentProfile() {
        Task {
            await addAppToProfileAsync(nil)
        }
    }
    
    private func addAppToProfile(_ profile: SmartProfile) {
        Task {
            await addAppToProfileAsync(profile)
        }
    }
    
    private func addAppToProfileAsync(_ targetProfile: SmartProfile?) async {
        do {
            // Get current URL or use app URL
            let urlToAdd = webPage.url?.absoluteString ?? app.url
            
            // Get AppsViewModel instance
            let appsViewModel = AppsViewModel()
            
            // Add app with metadata
            let _ = try await appsViewModel.addAppWithMetadata(
                url: urlToAdd,
                to: targetProfile?.id
            )
            
            HapticManager.notification(.success)
            
            // Show confirmation
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showAddedConfirmation = true
                }
            }
            
            // Hide confirmation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showAddedConfirmation = false
                }
            }
            
        } catch {
            print("Failed to add app: \(error)")
            HapticManager.notification(.error)
            // TODO: Show error alert
        }
    }
}

// MARK: - WebView SwiftUI Wrapper
struct WebView: UIViewRepresentable {
    let page: WebPage
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Enable zoom
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 5.0
        
        // Connect to WebPage observable
        context.coordinator.connectToWebPage(page, webView: webView)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Updates handled by WebPage observable
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        private var webView: WKWebView?
        private var webPage: WebPage?
        private var observations: [NSKeyValueObservation] = []
        
        func connectToWebPage(_ page: WebPage, webView: WKWebView) {
            self.webPage = page
            self.webView = webView
            
            // Observe WebKit properties
            observations = [
                webView.observe(\.estimatedProgress) { [weak page] webView, _ in
                    DispatchQueue.main.async {
                        page?.estimatedProgress = webView.estimatedProgress
                    }
                },
                webView.observe(\.isLoading) { [weak page] webView, _ in
                    DispatchQueue.main.async {
                        page?.isLoading = webView.isLoading
                    }
                },
                webView.observe(\.url) { [weak page] webView, _ in
                    DispatchQueue.main.async {
                        page?.url = webView.url
                    }
                },
                webView.observe(\.title) { [weak page] webView, _ in
                    DispatchQueue.main.async {
                        page?.title = webView.title ?? ""
                    }
                },
                webView.observe(\.canGoBack) { [weak page] webView, _ in
                    DispatchQueue.main.async {
                        page?.canGoBack = webView.canGoBack
                    }
                },
                webView.observe(\.canGoForward) { [weak page] webView, _ in
                    DispatchQueue.main.async {
                        page?.canGoForward = webView.canGoForward
                    }
                }
            ]
            
            // Handle WebPage commands
            page.onLoadRequest = { [weak webView] request in
                webView?.load(request)
            }
            
            page.onGoBack = { [weak webView] in
                webView?.goBack()
            }
            
            page.onGoForward = { [weak webView] in
                webView?.goForward()
            }
            
            page.onReload = { [weak webView] in
                webView?.reload()
            }
            
            page.onStopLoading = { [weak webView] in
                webView?.stopLoading()
            }
        }
        
        deinit {
            observations.forEach { $0.invalidate() }
        }
        
        // MARK: - UIScrollViewDelegate
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            NotificationCenter.default.post(
                name: .webViewDidScroll,
                object: nil,
                userInfo: ["offset": scrollView.contentOffset.y]
            )
        }
    }
}

// MARK: - WebPage Observable
@MainActor
class WebPage: ObservableObject {
    @Published var url: URL?
    @Published var title: String = ""
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    
    // Commands
    var onLoadRequest: ((URLRequest) -> Void)?
    var onGoBack: (() -> Void)?
    var onGoForward: (() -> Void)?
    var onReload: (() -> Void)?
    var onStopLoading: (() -> Void)?
    
    func load(_ request: URLRequest) {
        onLoadRequest?(request)
    }
    
    func goBack() {
        onGoBack?()
    }
    
    func goForward() {
        onGoForward?()
    }
    
    func reload() {
        onReload?()
    }
    
    func stopLoading() {
        onStopLoading?()
    }
}

// MARK: - Scroll Change Modifier
struct ScrollChangeModifier: ViewModifier {
    let onChange: (CGFloat) -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .webViewDidScroll)) { notification in
                if let offset = notification.userInfo?["offset"] as? CGFloat {
                    onChange(offset)
                }
            }
    }
}

extension View {
    func onScrollChanged(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        modifier(ScrollChangeModifier(onChange: onChange))
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let webViewDidScroll = Notification.Name("webViewDidScroll")
}

// MARK: - Confirmation View
struct AddedConfirmationView: View {
    @Binding var isVisible: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            if isVisible {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                    
                    Text("Added to Apps")
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(DesignTokens.GlassEffect.regular)
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
            
            Spacer()
        }
    }
}