import SwiftUI
import WebKit

// MARK: - Native Web Browser View
@available(iOS 17.0, *)
struct NativeWebBrowserView: View {
    let app: BookmarkedApp
    @Environment(\.dismiss) private var dismiss
    @StateObject private var webPage: WebPage
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showMenu = false
    @State private var showAddedConfirmation = false
    
    init(app: BookmarkedApp) {
        self.app = app
        self._webPage = StateObject(wrappedValue: WebPage.from(app: app))
    }
    
    var body: some View {
        NavigationStack {
            WebView(webPage: webPage)
                .ignoresSafeArea()
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
                .onSubmit(of: .search) {
                    loadURL(searchText)
                }
                .toolbar {
                    // Top toolbar items only
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 4) {
                            if webPage.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            
                            if let url = webPage.url {
                                Text(url.host ?? url.absoluteString)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .frame(maxWidth: 200)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: { addApp() }) {
                                Label("Add to Apps", systemImage: "plus.app")
                            }
                            
                            Divider()
                            
                            Button(action: { shareCurrentPage() }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(action: { webPage.reload() }) {
                                Label("Reload", systemImage: "arrow.clockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color.black, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .overlay(
            ConfirmationView(
                isVisible: $showAddedConfirmation,
                message: "Added to Apps"
            )
        )
        .onAppear {
            loadInitialURL()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadInitialURL() {
        guard let url = URL(string: app.url) else { return }
        let request = URLRequest(url: url)
        webPage.load(request)
    }
    
    private func loadURL(_ urlString: String) {
        if urlString.contains(".") || urlString.hasPrefix("http") {
            var finalURL = urlString
            if !finalURL.hasPrefix("http") {
                finalURL = "https://\(finalURL)"
            }
            
            if let url = URL(string: finalURL) {
                let request = URLRequest(url: url)
                webPage.load(request)
            }
        } else {
            let searchQuery = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let searchURL = URL(string: "https://www.google.com/search?q=\(searchQuery)") {
                let request = URLRequest(url: searchURL)
                webPage.load(request)
            }
        }
    }
    
    private func shareCurrentPage() {
        guard let url = webPage.url else { return }
        
        HapticManager.impact(.medium)
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootViewController.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 100, width: 0, height: 0)
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func addApp() {
        // Add app to active profile - implementation depends on your app logic
        showAddedConfirmation = true
        HapticManager.impact(.light)
    }
}

// MARK: - Simple Web View
@available(iOS 15.0, *)
struct WebView: UIViewRepresentable {
    @ObservedObject var webPage: WebPage
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.suppressesIncrementalRendering = false
        
        // Web3 injection script
        if let web3Script = createWeb3InjectionScript() {
            let userScript = WKUserScript(source: web3Script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            config.userContentController.addUserScript(userScript)
        }
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.allowsBackForwardNavigationGestures = true
        
        context.coordinator.connect(to: webPage, webView: webView)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Updates handled by WebPage observable
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func createWeb3InjectionScript() -> String? {
        // Basic Web3 injection for dApp compatibility
        return """
        if (window.ethereum) {
            console.log('Ethereum provider already exists');
        } else {
            window.ethereum = {
                isMetaMask: true,
                isInterspace: true,
                request: function(args) {
                    window.webkit.messageHandlers.ethereum.postMessage(args);
                    return new Promise(function(resolve, reject) {
                        // Handle promise resolution via message handler
                    });
                },
                on: function(event, callback) {
                    // Event handling
                },
                removeListener: function(event, callback) {
                    // Remove listener
                }
            };
            window.web3 = { currentProvider: window.ethereum };
        }
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        private weak var webPage: WebPage?
        private weak var webView: WKWebView?
        
        func connect(to webPage: WebPage, webView: WKWebView) {
            self.webPage = webPage
            self.webView = webView
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            webPage?.isLoading = true
            webPage?.url = webView.url
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webPage?.isLoading = false
            webPage?.title = webView.title ?? ""
            webPage?.url = webView.url
            webPage?.canGoBack = webView.canGoBack
            webPage?.canGoForward = webView.canGoForward
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            webPage?.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            webPage?.isLoading = false
        }
    }
}

// MARK: - Simple Confirmation View
struct ConfirmationView: View {
    @Binding var isVisible: Bool
    let message: String
    
    var body: some View {
        if isVisible {
            VStack {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(message)
                        .font(.system(size: 16, weight: .medium))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(25)
                .shadow(radius: 10)
            }
            .padding(.top, 50)
            .frame(maxHeight: .infinity, alignment: .top)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isVisible = false
                    }
                }
            }
        }
    }
}