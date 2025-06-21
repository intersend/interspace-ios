import Foundation
import WebKit

// MARK: - Website Metadata
struct WebsiteMetadata {
    let title: String
    let description: String?
    let iconURL: String?
    let themeColor: String?
    let canonicalURL: String?
}

// MARK: - Metadata Fetcher
@MainActor
class MetadataFetcher: NSObject, ObservableObject {
    static let shared = MetadataFetcher()
    
    private let webView: WKWebView
    private var completionHandlers: [URL: [(Result<WebsiteMetadata, Error>) -> Void]] = [:]
    
    private override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        self.webView.navigationDelegate = self
    }
    
    func fetchMetadata(for url: URL) async throws -> WebsiteMetadata {
        return try await withCheckedThrowingContinuation { continuation in
            fetchMetadata(for: url) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    private func fetchMetadata(for url: URL, completion: @escaping (Result<WebsiteMetadata, Error>) -> Void) {
        // Check if we're already fetching this URL
        if completionHandlers[url] != nil {
            completionHandlers[url]?.append(completion)
            return
        }
        
        // Start new fetch
        completionHandlers[url] = [completion]
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    private func extractMetadata() async throws -> WebsiteMetadata {
        let jsCode = """
        (function() {
            var metadata = {
                title: document.title || '',
                description: '',
                iconURL: '',
                themeColor: '',
                canonicalURL: ''
            };
            
            // Get description
            var metaDesc = document.querySelector('meta[property="og:description"]') || 
                          document.querySelector('meta[name="description"]');
            if (metaDesc) metadata.description = metaDesc.content;
            
            // Get icon - try multiple sources
            var icons = [
                document.querySelector('link[rel="apple-touch-icon"]'),
                document.querySelector('link[rel="apple-touch-icon-precomposed"]'),
                document.querySelector('link[rel="icon"][type="image/png"]'),
                document.querySelector('link[rel="icon"][type="image/svg+xml"]'),
                document.querySelector('link[rel="shortcut icon"]'),
                document.querySelector('link[rel="icon"]')
            ];
            
            for (var icon of icons) {
                if (icon && icon.href) {
                    metadata.iconURL = icon.href;
                    break;
                }
            }
            
            // Fallback to favicon.ico
            if (!metadata.iconURL) {
                metadata.iconURL = window.location.origin + '/favicon.ico';
            }
            
            // Get theme color
            var themeColor = document.querySelector('meta[name="theme-color"]');
            if (themeColor) metadata.themeColor = themeColor.content;
            
            // Get canonical URL
            var canonical = document.querySelector('link[rel="canonical"]');
            if (canonical) metadata.canonicalURL = canonical.href;
            
            return metadata;
        })();
        """
        
        return try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let dict = result as? [String: Any] else {
                    continuation.resume(throwing: MetadataError.invalidFormat)
                    return
                }
                
                let metadata = WebsiteMetadata(
                    title: dict["title"] as? String ?? "",
                    description: dict["description"] as? String,
                    iconURL: dict["iconURL"] as? String,
                    themeColor: dict["themeColor"] as? String,
                    canonicalURL: dict["canonicalURL"] as? String
                )
                
                continuation.resume(returning: metadata)
            }
        }
    }
    
    private func completeRequests(for url: URL, with result: Result<WebsiteMetadata, Error>) {
        guard let handlers = completionHandlers[url] else { return }
        completionHandlers[url] = nil
        
        for handler in handlers {
            handler(result)
        }
    }
}

// MARK: - WKNavigationDelegate
extension MetadataFetcher: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            guard let url = webView.url else { return }
            
            do {
                let metadata = try await extractMetadata()
                completeRequests(for: url, with: .success(metadata))
            } catch {
                completeRequests(for: url, with: .failure(error))
            }
        }
    }
    
    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            guard let url = webView.url else { return }
            completeRequests(for: url, with: .failure(error))
        }
    }
    
    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            guard let url = webView.url else { return }
            completeRequests(for: url, with: .failure(error))
        }
    }
}

// MARK: - Metadata Error
enum MetadataError: LocalizedError {
    case invalidFormat
    case fetchFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid metadata format"
        case .fetchFailed:
            return "Failed to fetch metadata"
        }
    }
}

// MARK: - Icon Generator
struct IconGenerator {
    static func generateIcon(for text: String, size: CGSize = CGSize(width: 120, height: 120)) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background gradient
            let colors = [
                UIColor.systemBlue.cgColor,
                UIColor.systemPurple.cgColor
            ]
            
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            )!
            
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: size.width * 0.225)
            path.addClip()
            
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            
            // Text
            let letter = String(text.prefix(1)).uppercased()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.width * 0.4, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            
            let textSize = letter.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            letter.draw(in: textRect, withAttributes: attributes)
        }
    }
}