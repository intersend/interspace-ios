import Foundation
import Combine
import WebKit

// MARK: - WebPage
/// Observable model for managing web page state and navigation
/// Implements iOS 26 WebPage pattern for SwiftUI integration
class WebPage: ObservableObject {
    // MARK: - Published Properties
    
    @Published var url: URL?
    @Published var title: String = ""
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0.0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var error: Error?
    
    // MARK: - Navigation Actions
    
    var onLoadRequest: ((URLRequest) -> Void)?
    var onLoadURL: ((URL) -> Void)?
    var onGoBack: (() -> Void)?
    var onGoForward: (() -> Void)?
    var onReload: (() -> Void)?
    var onStopLoading: (() -> Void)?
    var onEvaluateJavaScript: ((String, @escaping (Any?, Error?) -> Void) -> Void)?
    
    // MARK: - Initialization
    
    init(url: URL? = nil) {
        self.url = url
    }
    
    // MARK: - Public Methods
    
    /// Load a URL
    func load(_ url: URL) {
        self.url = url
        onLoadURL?(url)
    }
    
    /// Load a URL request
    func load(_ request: URLRequest) {
        self.url = request.url
        onLoadRequest?(request)
    }
    
    /// Navigate back
    func goBack() {
        onGoBack?()
    }
    
    /// Navigate forward
    func goForward() {
        onGoForward?()
    }
    
    /// Reload the current page
    func reload() {
        onReload?()
    }
    
    /// Stop loading the current page
    func stopLoading() {
        onStopLoading?()
    }
    
    /// Execute JavaScript on the page
    func evaluateJavaScript(_ script: String, completion: @escaping (Any?, Error?) -> Void) {
        onEvaluateJavaScript?(script, completion)
    }
    
    /// Reset error state
    func clearError() {
        error = nil
    }
}

// MARK: - WebPage Extensions for iOS 26
extension WebPage {
    /// Create a web page for a bookmarked app
    static func from(app: BookmarkedApp) -> WebPage {
        guard let appURL = URL(string: app.url) else {
            return WebPage()
        }
        return WebPage(url: appURL)
    }
    
    /// Check if the page is secure (HTTPS)
    var isSecure: Bool {
        url?.scheme == "https"
    }
    
    /// Get the host name for display
    var displayHost: String {
        url?.host ?? ""
    }
    
    /// Get a short display title
    var displayTitle: String {
        if !title.isEmpty {
            return title
        } else if let host = url?.host {
            return host
        } else {
            return "New Page"
        }
    }
}