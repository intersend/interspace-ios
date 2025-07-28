import Foundation
import Starscream
import WalletConnectRelay

private class StarscreamWebSocket: WebSocketConnecting, WebSocketDelegate {
    private let socket: WebSocket
    private var _isConnected: Bool = false
    
    var isConnected: Bool { _isConnected }
    var onConnect: (() -> Void)?
    var onDisconnect: ((Error?) -> Void)?
    var onText: ((String) -> Void)?
    
    var request: URLRequest {
        get { socket.request }
        set { socket.request = newValue }
    }
    
    init(socket: WebSocket) {
        self.socket = socket
        self.socket.delegate = self
    }
    
    func connect() {
        socket.connect()
    }
    
    func disconnect() {
        socket.disconnect()
    }
    
    func write(string: String, completion: (() -> Void)?) {
        socket.write(string: string, completion: completion)
    }
    
    // MARK: - WebSocketDelegate
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected:
            _isConnected = true
            onConnect?()
        case .disconnected(let reason, let code):
            _isConnected = false
            let error = NSError(domain: "WebSocket", code: Int(code), userInfo: [NSLocalizedDescriptionKey: reason])
            onDisconnect?(error)
        case .text(let string):
            onText?(string)
        case .cancelled:
            _isConnected = false
            onDisconnect?(nil)
        case .error(let err):
            _isConnected = false
            onDisconnect?(err)
        default:
            break
        }
    }
}

struct DefaultSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        var request = URLRequest(url: url)
        let socket = WebSocket(request: request)
        let queue = DispatchQueue(label: "com.walletconnect.sdk.sockets", qos: .utility, attributes: .concurrent)
        socket.callbackQueue = queue
        return StarscreamWebSocket(socket: socket)
    }
}
