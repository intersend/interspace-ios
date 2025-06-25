import SwiftUI
import WebKit

struct InjectedWebView: UIViewRepresentable {
    let page: WebPage
    
    func makeUIView(context: Context) -> WKWebView {
        // Use WalletInjector configuration
        let configuration = WalletInjector.shared.createConfiguration()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
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
    
    class Coordinator: NSObject, WKNavigationDelegate {
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
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if WalletInjector.shared.debugLogging {
                print("[OrbySample] Page loaded: \(webView.url?.absoluteString ?? "unknown")")
                
                // Log injected provider info
                webView.evaluateJavaScript("window.ethereum ? 'Provider injected' : 'No provider'") { result, error in
                    if let result = result {
                        print("[OrbySample] Injection status: \(result)")
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            // Allow all responses
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("[OrbySample] Navigation failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("[OrbySample] Provisional navigation failed: \(error.localizedDescription)")
        }
    }
}