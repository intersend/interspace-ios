import Foundation
import WebKit
import Combine

/// Service to handle Web3 messages from the injected JavaScript
/// Routes dApp requests to the appropriate services and returns responses
@MainActor
final class Web3MessageHandler: NSObject, WKScriptMessageHandler {
    
    // MARK: - Singleton
    
    static let shared = Web3MessageHandler()
    
    // MARK: - Properties
    
    private let transactionApprovalService = TransactionApprovalService.shared
    private let profileViewModel = ProfileViewModel.shared
    private var cancellables = Set<AnyCancellable>()
    private weak var webView: WKWebView?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let messageType = body["type"] as? String else {
            print("❌ Web3MessageHandler: Invalid message format")
            return
        }
        
        print("📨 Web3MessageHandler: Received message:", messageType)
        
        Task {
            await handleMessage(messageType: messageType, body: body)
        }
    }
    
    // MARK: - Public Methods
    
    /// Configure the web view with web3 injection
    func configureWebView(_ webView: WKWebView) {
        self.webView = webView
        
        // Add message handler
        webView.configuration.userContentController.add(self, name: "interspaceWeb3")
        
        // Inject web3 script
        injectWeb3Script(into: webView)
        
        print("✅ Web3MessageHandler: Configured web view with web3 injection")
    }
    
    /// Send response back to JavaScript
    func sendResponse(_ response: Web3Response) {
        guard let webView = webView else { return }
        
        let responseData: [String: Any] = [
            "type": response.type.rawValue,
            "id": response.id,
            "result": response.result as Any,
            "error": response.error as Any
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: responseData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            let script = "window.__handleInterspaceMessage(\(jsonString));"
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("❌ Web3MessageHandler: Error sending response:", error)
                }
            }
        } catch {
            print("❌ Web3MessageHandler: Error serializing response:", error)
        }
    }
    
    /// Send web3 event to JavaScript
    func sendEvent(_ event: Web3Event) {
        guard let webView = webView else { return }
        
        let eventData: [String: Any] = [
            "type": "web3_event",
            "event": event.event,
            "data": event.data
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: eventData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            let script = "window.__handleInterspaceMessage(\(jsonString));"
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("❌ Web3MessageHandler: Error sending event:", error)
                }
            }
        } catch {
            print("❌ Web3MessageHandler: Error serializing event:", error)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleMessage(messageType: String, body: [String: Any]) async {
        switch messageType {
        case "get_initial_state":
            await handleGetInitialState(body: body)
        case "web3_request":
            await handleWeb3Request(body: body)
        case "injection_complete":
            await handleInjectionComplete(body: body)
        default:
            print("❌ Web3MessageHandler: Unknown message type:", messageType)
        }
    }
    
    private func handleGetInitialState(body: [String: Any]) async {
        guard let profile = profileViewModel.profile else {
            sendResponse(Web3Response(
                type: .initialState,
                id: 0,
                result: nil,
                error: ["message": "No active profile"]
            ))
            return
        }
        
        // Get MPC wallet address from profile
        let mpcAddress = profile.sessionWalletAddress
        let chainId = "0x1" // Ethereum mainnet for now
        let accounts = [mpcAddress]
        
        // Send initial state with MPC address
        sendResponse(Web3Response(
            type: .initialState,
            id: 0,
            result: [
                "chainId": chainId,
                "accounts": accounts,
                "isConnected": true
            ],
            error: nil
        ))
        
        print("✅ Web3MessageHandler: Sent initial state with MPC address:", mpcAddress)
    }
    
    private func handleWeb3Request(body: [String: Any]) async {
        guard let id = body["id"] as? Int,
              let method = body["method"] as? String,
              let params = body["params"] as? [Any] else {
            print("❌ Web3MessageHandler: Invalid web3 request format")
            return
        }
        
        print("🔄 Web3MessageHandler: Processing web3 request:", method)
        
        switch method {
        case "eth_requestAccounts", "eth_accounts":
            await handleEthAccounts(id: id)
        case "eth_chainId":
            await handleEthChainId(id: id)
        case "net_version":
            await handleNetVersion(id: id)
        case "eth_sendTransaction":
            await handleEthSendTransaction(id: id, params: params)
        case "eth_signTransaction":
            await handleEthSignTransaction(id: id, params: params)
        case "eth_sign", "personal_sign":
            await handleEthSign(id: id, params: params)
        case "eth_signTypedData_v3", "eth_signTypedData_v4":
            await handleEthSignTypedData(id: id, params: params)
        default:
            sendResponse(Web3Response(
                type: .web3Response,
                id: id,
                result: nil,
                error: ["message": "Method not supported: \(method)"]
            ))
        }
    }
    
    private func handleInjectionComplete(body: [String: Any]) async {
        guard let url = body["url"] as? String else { return }
        print("✅ Web3MessageHandler: Injection complete for URL:", url)
        
        // Send connect event with initial state
        await handleGetInitialState(body: body)
    }
    
    // MARK: - Web3 Method Handlers
    
    private func handleEthAccounts(id: Int) async {
        guard let profile = profileViewModel.profile else {
            sendResponse(Web3Response(
                type: .web3Response,
                id: id,
                result: [],
                error: nil
            ))
            return
        }
        
        let mpcAddress = profile.sessionWalletAddress
        sendResponse(Web3Response(
            type: .web3Response,
            id: id,
            result: [mpcAddress],
            error: nil
        ))
    }
    
    private func handleEthChainId(id: Int) async {
        sendResponse(Web3Response(
            type: .web3Response,
            id: id,
            result: "0x1", // Ethereum mainnet
            error: nil
        ))
    }
    
    private func handleNetVersion(id: Int) async {
        sendResponse(Web3Response(
            type: .web3Response,
            id: id,
            result: "1", // Ethereum mainnet
            error: nil
        ))
    }
    
    private func handleEthSendTransaction(id: Int, params: [Any]) async {
        guard let profile = profileViewModel.profile,
              let txParams = params.first as? [String: Any] else {
            sendResponse(Web3Response(
                type: .web3Response,
                id: id,
                result: nil,
                error: ["message": "Invalid transaction parameters"]
            ))
            return
        }
        
        let mpcAddress = profile.sessionWalletAddress
        
        do {
            // Route transaction through TransactionApprovalService
            let txHash = try await transactionApprovalService.routeTransaction(
                params: txParams,
                mpcAddress: mpcAddress,
                profile: profile
            )
            
            sendResponse(Web3Response(
                type: .web3Response,
                id: id,
                result: txHash,
                error: nil
            ))
            
            print("✅ Web3MessageHandler: Transaction sent successfully:", txHash)
            
        } catch {
            print("❌ Web3MessageHandler: Transaction failed:", error)
            sendResponse(Web3Response(
                type: .web3Response,
                id: id,
                result: nil,
                error: ["message": error.localizedDescription]
            ))
        }
    }
    
    private func handleEthSignTransaction(id: Int, params: [Any]) async {
        // For now, redirect to send transaction
        await handleEthSendTransaction(id: id, params: params)
    }
    
    private func handleEthSign(id: Int, params: [Any]) async {
        guard let profile = profileViewModel.profile,
              params.count >= 2,
              let address = params[0] as? String,
              let message = params[1] as? String else {
            sendResponse(Web3Response(
                type: .web3Response,
                id: id,
                result: nil,
                error: ["message": "Invalid sign parameters"]
            ))
            return
        }
        
        let mpcAddress = profile.sessionWalletAddress
        
        do {
            // Route message signing through TransactionApprovalService
            let signature = try await transactionApprovalService.signMessage(
                message,
                mpcAddress: mpcAddress,
                profile: profile
            )
            
            sendResponse(Web3Response(
                type: .web3Response,
                id: id,
                result: signature,
                error: nil
            ))
            
            print("✅ Web3MessageHandler: Message signed successfully")
            
        } catch {
            print("❌ Web3MessageHandler: Message signing failed:", error)
            sendResponse(Web3Response(
                type: .web3Response,
                id: id,
                result: nil,
                error: ["message": error.localizedDescription]
            ))
        }
    }
    
    private func handleEthSignTypedData(id: Int, params: [Any]) async {
        // For now, treat as regular message signing
        await handleEthSign(id: id, params: params)
    }
    
    // MARK: - Script Injection
    
    private func injectWeb3Script(into webView: WKWebView) {
        guard let scriptPath = Bundle.main.path(forResource: "web3-injection", ofType: "js"),
              let scriptContent = try? String(contentsOfFile: scriptPath) else {
            print("❌ Web3MessageHandler: Could not load web3-injection.js")
            return
        }
        
        let userScript = WKUserScript(
            source: scriptContent,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        
        webView.configuration.userContentController.addUserScript(userScript)
        print("✅ Web3MessageHandler: Injected web3 script")
    }
}

// MARK: - Supporting Types

/// Web3 response structure
struct Web3Response {
    let type: Web3ResponseType
    let id: Int
    let result: Any?
    let error: [String: Any]?
}

/// Web3 response types
enum Web3ResponseType: String {
    case web3Response = "web3_response"
    case initialState = "initial_state"
}

/// Web3 event structure
struct Web3Event {
    let event: String
    let data: [String: Any]
}

/// Web3 event types
enum Web3EventType: String {
    case connect = "connect"
    case disconnect = "disconnect"
    case accountsChanged = "accountsChanged"
    case chainChanged = "chainChanged"
}