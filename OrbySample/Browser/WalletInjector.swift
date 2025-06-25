import Foundation
import WebKit

enum WalletProvider: String, CaseIterable {
    case metamask = "metamask"
    case coinbase = "coinbase"
    case walletConnect = "walletconnect"
    case trust = "trust"
    case rainbow = "rainbow"
    
    var displayName: String {
        switch self {
        case .metamask: return "MetaMask"
        case .coinbase: return "Coinbase Wallet"
        case .walletConnect: return "WalletConnect"
        case .trust: return "Trust Wallet"
        case .rainbow: return "Rainbow"
        }
    }
    
    var providerInfo: EIP6963ProviderInfo {
        switch self {
        case .metamask:
            return EIP6963ProviderInfo(
                uuid: "350670db-19fa-4704-a166-e52e178b59d4",
                name: "MetaMask",
                icon: "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzMiIGhlaWdodD0iMzIiIHZpZXdCb3g9IjAgMCAzMyAzMiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cGF0aCBkPSJNMzAuOTE3NSAyLjMzMzMzTDE4LjUgMTEuNjY2N0wyMC43NSA3LjAwMDAxTDMwLjkxNzUgMi4zMzMzM1oiIGZpbGw9IiNFMjc2MjUiLz48L3N2Zz4=",
                rdns: "io.metamask"
            )
        case .coinbase:
            return EIP6963ProviderInfo(
                uuid: "f39d8f11-dfe8-4f73-92d8-1d5e30036e36",
                name: "Coinbase Wallet",
                icon: "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzIiIGhlaWdodD0iMzIiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PHBhdGggZD0iTTE2IDMyQzcuMTYzIDMyIDAgMjQuODM3IDAgMTZTNy4xNjMgMCAxNiAwczE2IDcuMTYzIDE2IDE2LTcuMTYzIDE2LTE2IDE2WiIgZmlsbD0iIzAwNTJGRiIvPjwvc3ZnPg==",
                rdns: "com.coinbase.wallet"
            )
        case .walletConnect:
            return EIP6963ProviderInfo(
                uuid: "8a4f3b6e-2c7d-4f91-8e3a-6b9d5f0e1c2a",
                name: "WalletConnect",
                icon: "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMzIiIGhlaWdodD0iMzIiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PHBhdGggZD0iTTkuNTggMTEuODNjMy40NC0zLjM3IDkuMDMtMy4zNyAxMi40NyAwbDEuMzEgMS4yOGMuMTcuMTcuMTcuNDQgMCAuNjFsLTQuNDggNC4zOWMtLjA5LjA4LS4yMy4wOC0uMzEgMGwtMS44LTEuNzZjLTIuNC0yLjM1LTYuMy0yLjM1LTguNyAwbC0xLjkzIDEuODljLS4wOS4wOC0uMjMuMDgtLjMxIDBMMS4zNSAxMy44NWMtLjE3LS4xNy0uMTctLjQ0IDAtLjYxbDguMjMtOC4wNloiIGZpbGw9IiMzQjk5RkMiLz48L3N2Zz4=",
                rdns: "com.walletconnect.web3wallet"
            )
        case .trust:
            return EIP6963ProviderInfo(
                uuid: "7b4f3c5e-8d2a-4f91-8e3b-6a9d5f0e1c3b",
                name: "Trust Wallet",
                icon: "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjQiIGhlaWdodD0iNjQiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PHBhdGggZD0iTTMyIDY0QzE0LjMyNyA2NCAwIDQ5LjY3MyAwIDMyUzE0LjMyNyAwIDMyIDBzMzIgMTQuMzI3IDMyIDMyLTE0LjMyNyAzMi0zMiAzMloiIGZpbGw9IiMzMzc1QkIiLz48L3N2Zz4=",
                rdns: "com.trustwallet.app"
            )
        case .rainbow:
            return EIP6963ProviderInfo(
                uuid: "9c5e4f8a-3b7d-4f91-8e3c-6a9d5f0e1c4c",
                name: "Rainbow",
                icon: "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cGF0aCBkPSJNMjAgMzhDMjAgMTcuMDEzIDM3LjAxMyAwIDU4IDBoNHY3NmMwIDIwLjk4Ny0xNy4wMTMgMzgtMzggMzgtMjAuOTg3IDAtMzgtMTcuMDEzLTM4LTM4VjMwaDRjNi42MjcgMCAxMiA1LjM3MyAxMiAxMnYxNmMwIDYuNjI3IDUuMzczIDEyIDEyIDEyczEyLTUuMzczIDEyLTEyVjM4WiIgZmlsbD0iIzBFNzZGRCIvPjwvc3ZnPg==",
                rdns: "me.rainbow"
            )
        }
    }
}

@MainActor
class WalletInjector: ObservableObject {
    static let shared = WalletInjector()
    
    @Published var selectedProvider: WalletProvider = .metamask
    @Published var testAddress: String = "0x742d35Cc6634C0532925a3b844Bc9e7595f6BEDb"
    @Published var chainId: Int = 1
    @Published var autoConnect: Bool = true
    @Published var debugLogging: Bool = true
    
    private init() {}
    
    func createConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        // Inject wallet provider scripts
        let userContentController = WKUserContentController()
        
        // Add message handler for wallet bridge
        userContentController.add(WalletMessageHandler(), name: "walletBridge")
        
        // Inject EIP-6963 provider announcement script
        if let announceScript = createEIP6963Script() {
            userContentController.addUserScript(announceScript)
        }
        
        // Inject main provider script
        if let providerScript = createProviderScript() {
            userContentController.addUserScript(providerScript)
        }
        
        configuration.userContentController = userContentController
        
        return configuration
    }
    
    private func createEIP6963Script() -> WKUserScript? {
        let providerInfo = selectedProvider.providerInfo
        let script = """
        (function() {
            // EIP-6963 Provider Announcement
            const info = {
                uuid: '\(providerInfo.uuid)',
                name: '\(providerInfo.name)',
                icon: '\(providerInfo.icon)',
                rdns: '\(providerInfo.rdns)'
            };
            
            // Create provider object
            const provider = window.ethereum || {};
            
            // Announce provider when requested
            window.addEventListener('eip6963:requestProvider', () => {
                if (\(debugLogging ? "true" : "false")) {
                    console.log('[OrbySample] EIP-6963: Announcing provider', info);
                }
                
                window.dispatchEvent(new CustomEvent('eip6963:announceProvider', {
                    detail: {
                        info: info,
                        provider: provider
                    }
                }));
            });
            
            // Auto-announce on load
            setTimeout(() => {
                window.dispatchEvent(new CustomEvent('eip6963:announceProvider', {
                    detail: {
                        info: info,
                        provider: provider
                    }
                }));
            }, 100);
        })();
        """
        
        return WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }
    
    private func createProviderScript() -> WKUserScript? {
        let script = WalletProviderScripts.generateEthereumProviderScript(
            provider: selectedProvider,
            testAddress: testAddress,
            chainId: chainId,
            autoConnect: autoConnect,
            debugMode: debugLogging
        )
        
        return WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }
}

// Message handler for wallet bridge
class WalletMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let messageId = body["id"] as? String,
              let method = body["method"] as? String else {
            return
        }
        
        let params = body["params"] as? [Any] ?? []
        let address = body["address"] as? String
        let chainId = body["chainId"] as? Int ?? 1
        
        // Handle RPC methods
        Task { @MainActor in
            do {
                let result = try await handleRPCMethod(method: method, params: params, address: address, chainId: chainId)
                
                // Send response back to JavaScript
                if let webView = message.webView {
                    let response = """
                    window.__handleWalletResponse('\(messageId)', null, \(encodeJSON(result)));
                    """
                    webView.evaluateJavaScript(response)
                }
            } catch {
                // Send error back to JavaScript
                if let webView = message.webView {
                    let response = """
                    window.__handleWalletResponse('\(messageId)', '\(error.localizedDescription)', null);
                    """
                    webView.evaluateJavaScript(response)
                }
            }
        }
    }
    
    private func handleRPCMethod(method: String, params: [Any], address: String?, chainId: Int) async throws -> Any {
        let injector = WalletInjector.shared
        
        // Use MockWalletProvider for responses
        let result = MockWalletProvider.mockResponse(
            for: method,
            params: params,
            address: address ?? injector.testAddress.lowercased(),
            chainId: chainId
        )
        
        if result == nil {
            if injector.debugLogging {
                print("[OrbySample] Unhandled RPC method: \(method)")
            }
            throw NSError(domain: "WalletInjector", code: -1, userInfo: [NSLocalizedDescriptionKey: "Method not supported: \(method)"])
        }
        
        return result!
    }
    
    private func encodeJSON(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let string = String(data: data, encoding: .utf8) else {
            return "null"
        }
        return string
    }
}