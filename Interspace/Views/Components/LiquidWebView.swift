import SwiftUI
import WebKit

// MARK: - Liquid Web View
/// Enhanced WebView with Liquid Glass design
@available(iOS 15.0, *)
struct LiquidWebView: View {
    @ObservedObject var page: Interspace.WebPage  // Custom WebPage model, not iOS 18.4
    @Binding var isFullScreen: Bool
    @State private var showStatusBar = true
    @State private var contentOffset: CGFloat = 0
    
    var body: some View {
        Group {
            #if swift(>=5.9)
            if #available(iOS 26.0, *) {
                // iOS 26 with full liquid glass design
                ZStack {
                    // Native WebView with enhanced capabilities
                    NativeWebView(
                        page: page,
                        contentOffset: $contentOffset,
                        isFullScreen: $isFullScreen
                    )
                    .ignoresSafeArea()
                    .statusBarHidden(!showStatusBar || isFullScreen)
                    
                    // Liquid glass overlay effects
                    LiquidGlassOverlay(
                        contentOffset: contentOffset,
                        isFullScreen: isFullScreen
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            } else if #available(iOS 17.0, *) {
                // iOS 17-25 with native WebView but simplified glass effects
                ZStack {
                    // Native WebView with enhanced capabilities
                    NativeWebView(
                        page: page,
                        contentOffset: $contentOffset,
                        isFullScreen: $isFullScreen
                    )
                    .ignoresSafeArea()
                    .statusBarHidden(!showStatusBar || isFullScreen)
                    
                    // Simplified glass effects for older iOS
                    SimplifiedGlassOverlay(
                        contentOffset: contentOffset,
                        isFullScreen: isFullScreen
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            } else {
                // iOS 16 and below
                LegacyWebView(page: page)
                    .ignoresSafeArea()
            }
            #else
            // Older Swift versions
            LegacyWebView(page: page)
                .ignoresSafeArea()
            #endif
        }
        .preferredColorScheme(.dark) // Liquid glass is optimized for dark mode
        .overlay(alignment: .topTrailing) {
            // Safari-style exit full-screen button
            if isFullScreen {
                Button(action: {
                    HapticManager.impact(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        isFullScreen = false
                    }
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                }
                .padding(.top, 60)
                .padding(.trailing, 16)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isFullScreen)
            }
        }
    }
}

// MARK: - Native Enhanced WebView
@available(iOS 17.0, *)
struct NativeWebView: UIViewRepresentable {
    @ObservedObject var page: Interspace.WebPage  // Custom WebPage model
    @Binding var contentOffset: CGFloat
    @Binding var isFullScreen: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let config = createConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        
        configureWebView(webView)
        configureWeb3(webView)
        configureLiquidGlass(webView)
        
        // Set delegates
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        
        // Connect to WebPage and bindings
        context.coordinator.connect(to: page, webView: webView)
        context.coordinator.contentOffset = $contentOffset
        context.coordinator.isFullScreen = $isFullScreen
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Updates handled by WebPage observable
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func createConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        
        // Media settings
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        
        // Performance settings
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.suppressesIncrementalRendering = false
        
        // Enhanced performance optimizations
        config.websiteDataStore = .default()
        config.processPool = WKProcessPool()
        config.applicationNameForUserAgent = "InterspaceBrowser/1.0"
        
        // iOS 17+ specific features
        if #available(iOS 17.0, *) {
            // Use valid WKPreferences properties
            config.preferences.javaScriptEnabled = true
            config.preferences.minimumFontSize = 0
            
            // Configure data detection for enhanced features
            config.dataDetectorTypes = .all
            
            // Enable developer extras if needed for debugging
            #if DEBUG
            config.preferences.setValue(true, forKey: "developerExtrasEnabled")
            #endif
        }
        
        return config
    }
    
    private func configureWebView(_ webView: WKWebView) {
        // Appearance
        webView.isOpaque = false
        
        // Performance optimizations
        webView.configuration.processPool = WKProcessPool()
        
        // Memory management
        if #available(iOS 16.4, *) {
            webView.configuration.preferences.isTextInteractionEnabled = true
        }
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        // Safari-like behavior
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.decelerationRate = .normal
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        
        // Zoom settings
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 5.0
        webView.scrollView.bouncesZoom = true
        
        // iOS 17+ enhanced scrolling
        if #available(iOS 17.0, *) {
            webView.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
    }
    
    private func configureLiquidGlass(_ webView: WKWebView) {
        // iOS 17+ Liquid Glass enhancements
        if #available(iOS 17.0, *) {
            // Enable advanced rendering for glass effects
            webView.layer.shouldRasterize = false
            webView.layer.allowsEdgeAntialiasing = true
            webView.layer.allowsGroupOpacity = true
            
            // Configure for optimal glass rendering
            webView.scrollView.layer.masksToBounds = false
            webView.scrollView.clipsToBounds = false
            
            // Enable smooth animations
            webView.layer.speed = 1.0
            webView.layer.timeOffset = 0.0
        }
    }
    
    private func configureWeb3(_ webView: WKWebView) {
        // Add message handler for Web3
        webView.configuration.userContentController.add(
            Web3MessageCoordinator.shared,
            name: "interspaceWeb3"
        )
        
        // Inject Web3 script
        if let scriptPath = Bundle.main.path(forResource: "web3-injection", ofType: "js"),
           let scriptContent = try? String(contentsOfFile: scriptPath) {
            
            let userScript = WKUserScript(
                source: scriptContent,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            
            webView.configuration.userContentController.addUserScript(userScript)
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
        private weak var page: Interspace.WebPage?  // Custom WebPage model
        private weak var webView: WKWebView?
        private var observations: [NSKeyValueObservation] = []
        var contentOffset: Binding<CGFloat>?
        var isFullScreen: Binding<Bool>?
        private var lastContentOffset: CGFloat = 0
        private var scrollVelocity: CGFloat = 0
        
        func connect(to page: Interspace.WebPage, webView: WKWebView) {  // Custom WebPage model
            self.page = page
            self.webView = webView
            
            setupObservations(for: webView)
            setupPageHandlers(for: webView)
        }
        
        private func setupObservations(for webView: WKWebView) {
            observations = [
                webView.observe(\.estimatedProgress) { [weak self] webView, _ in
                    DispatchQueue.main.async {
                        self?.page?.estimatedProgress = webView.estimatedProgress
                    }
                },
                webView.observe(\.isLoading) { [weak self] webView, _ in
                    DispatchQueue.main.async {
                        self?.page?.isLoading = webView.isLoading
                    }
                },
                webView.observe(\.url) { [weak self] webView, _ in
                    DispatchQueue.main.async {
                        self?.page?.url = webView.url
                    }
                },
                webView.observe(\.title) { [weak self] webView, _ in
                    DispatchQueue.main.async {
                        self?.page?.title = webView.title ?? ""
                    }
                },
                webView.observe(\.canGoBack) { [weak self] webView, _ in
                    DispatchQueue.main.async {
                        self?.page?.canGoBack = webView.canGoBack
                    }
                },
                webView.observe(\.canGoForward) { [weak self] webView, _ in
                    DispatchQueue.main.async {
                        self?.page?.canGoForward = webView.canGoForward
                    }
                }
            ]
        }
        
        private func setupPageHandlers(for webView: WKWebView) {
            page?.onLoadRequest = { [weak webView] request in
                webView?.load(request)
            }
            
            page?.onGoBack = { [weak webView] in
                webView?.goBack()
            }
            
            page?.onGoForward = { [weak webView] in
                webView?.goForward()
            }
            
            page?.onReload = { [weak webView] in
                webView?.reload()
            }
            
            page?.onStopLoading = { [weak webView] in
                webView?.stopLoading()
            }
            
            page?.onEvaluateJavaScript = { [weak webView] script, completion in
                webView?.evaluateJavaScript(script) { result, error in
                    completion(result, error)
                }
            }
        }
        
        deinit {
            observations.forEach { $0.invalidate() }
        }
        
        // MARK: - UIScrollViewDelegate
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let currentOffset = scrollView.contentOffset.y
            let velocity = scrollView.panGestureRecognizer.velocity(in: scrollView).y
            scrollVelocity = currentOffset - lastContentOffset
            lastContentOffset = currentOffset
            
            // Update binding
            contentOffset?.wrappedValue = currentOffset
            
            // Check for full screen mode based on scroll
            if scrollVelocity > 5 && currentOffset > 100 {
                // Scrolling down fast - enter full screen
                isFullScreen?.wrappedValue = true
            } else if scrollVelocity < -5 {
                // Scrolling up fast - exit full screen
                isFullScreen?.wrappedValue = false
            }
            
            NotificationCenter.default.post(
                name: .liquidWebViewDidScroll,
                object: nil,
                userInfo: [
                    "offset": currentOffset,
                    "velocity": velocity
                ]
            )
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Page finished loading
            // Additional scripts can be injected here if needed
        }
        
        // MARK: - WKUIDelegate
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Handle target="_blank" links
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

// MARK: - Legacy Web View
@available(iOS 15.0, *)
struct LegacyWebView: UIViewRepresentable {
    @ObservedObject var page: Interspace.WebPage  // Custom WebPage model
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.suppressesIncrementalRendering = false
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Safari-like scrolling
        webView.scrollView.decelerationRate = .normal
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        
        // Enable zoom
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 5.0
        
        // Configure Web3 injection
        Web3MessageHandler.shared.configureWebView(webView)
        
        // Connect to WebPage
        context.coordinator.connectToWebPage(page, webView: webView)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Updates handled by WebPage
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
            
            // Same observation setup as current implementation
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
            
            page.onEvaluateJavaScript = { [weak webView] script, completion in
                webView?.evaluateJavaScript(script) { result, error in
                    completion(result, error)
                }
            }
        }
        
        deinit {
            observations.forEach { $0.invalidate() }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            NotificationCenter.default.post(
                name: .liquidWebViewDidScroll,
                object: nil,
                userInfo: ["offset": scrollView.contentOffset.y]
            )
        }
    }
}

// MARK: - Web3 Message Coordinator
@MainActor
final class Web3MessageCoordinator: NSObject, WKScriptMessageHandler {
    static let shared = Web3MessageCoordinator()
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Forward to existing Web3MessageHandler
        Web3MessageHandler.shared.userContentController(userContentController, didReceive: message)
    }
}

// MARK: - WebPage Extensions
extension WebPage {
    var onPageDidFinish: (() -> Void)? {
        get { objc_getAssociatedObject(self, &PageDidFinishKey) as? (() -> Void) }
        set { objc_setAssociatedObject(self, &PageDidFinishKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

// Associated object keys
private var PageDidFinishKey: UInt8 = 0

// MARK: - Liquid Glass Overlay
@available(iOS 26.0, *)
struct LiquidGlassOverlay: View {
    let contentOffset: CGFloat
    let isFullScreen: Bool
    
    @State private var shimmerOffset: CGFloat = -1
    
    var body: some View {
        ZStack {
            // Top glass refraction effect
            VStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.white.opacity(refractionOpacity), location: 0),
                        .init(color: Color.white.opacity(0.05), location: 0.3),
                        .init(color: Color.clear, location: 1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .blur(radius: 3)
                .offset(y: isFullScreen ? -120 : 0)
                
                Spacer()
            }
            
            // Edge lensing effect
            GeometryReader { geometry in
                // Left edge
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.03),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 20)
                .blur(radius: 5)
                
                // Right edge
                HStack {
                    Spacer()
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.03),
                            Color.white.opacity(0.08)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 20)
                    .blur(radius: 5)
                }
            }
            
            // Dynamic shimmer based on scroll
            if abs(contentOffset) > 10 {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.clear, location: 0.3),
                        .init(color: Color.white.opacity(0.05), location: 0.5),
                        .init(color: Color.clear, location: 0.7)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(45))
                .offset(x: shimmerOffset * UIScreen.main.bounds.width)
                .opacity(shimmerOpacity)
                .animation(.linear(duration: 1.5), value: shimmerOffset)
            }
        }
        .onAppear {
            shimmerOffset = 2
        }
        .onChange(of: contentOffset) { _ in
            // Trigger shimmer on significant scroll
            if abs(contentOffset) > 50 {
                withAnimation {
                    shimmerOffset = shimmerOffset == 2 ? -1 : 2
                }
            }
        }
    }
    
    private var refractionOpacity: Double {
        // Dynamic opacity based on scroll position
        let normalized = min(max(contentOffset / 100, 0), 1)
        return 0.15 * (1 - normalized)
    }
    
    private var shimmerOpacity: Double {
        // Shimmer is more visible during fast scrolling
        let velocity = abs(contentOffset)
        return min(velocity / 200, 0.6)
    }
}

// MARK: - Simplified Glass Overlay (iOS 17-25)
@available(iOS 17.0, *)
struct SimplifiedGlassOverlay: View {
    let contentOffset: CGFloat
    let isFullScreen: Bool
    
    @State private var shimmerOffset: CGFloat = -1
    
    var body: some View {
        ZStack {
            // Basic glass effect using native Apple materials
            if !isFullScreen {
                VStack {
                    // Top glass gradient
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.1),
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .ignoresSafeArea()
                    
                    Spacer()
                    
                    // Bottom glass gradient
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.black.opacity(0.1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .ignoresSafeArea()
                }
            }
            
            // Simple shimmer effect
            if abs(contentOffset) > 10 {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.white.opacity(0.03),
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(45))
                .offset(x: shimmerOffset * UIScreen.main.bounds.width)
                .opacity(shimmerOpacity)
                .animation(.linear(duration: 2), value: shimmerOffset)
            }
        }
        .onAppear {
            shimmerOffset = 2
        }
        .onChange(of: contentOffset) { _ in
            if abs(contentOffset) > 50 {
                withAnimation {
                    shimmerOffset = shimmerOffset == 2 ? -1 : 2
                }
            }
        }
    }
    
    private var shimmerOpacity: Double {
        let velocity = abs(contentOffset)
        return min(velocity / 300, 0.3)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let liquidWebViewDidScroll = Notification.Name("liquidWebViewDidScroll")
}