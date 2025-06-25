import SwiftUI
import WebKit

struct MinimalBrowserView: View {
    @StateObject private var webPage = WebPage()
    @State private var searchText = ""
    @State private var showSearchOverlay = false
    @State private var showWalletSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Web Content
                InjectedWebView(page: webPage)
                    .ignoresSafeArea()
                    .onAppear {
                        loadInitialURL()
                    }
                
                // Top Progress Bar
                VStack {
                    if webPage.isLoading {
                        ProgressView(value: webPage.estimatedProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 2)
                            .transition(.opacity)
                    }
                    
                    Spacer()
                }
                .ignoresSafeArea()
                
                // Search Overlay
                if showSearchOverlay {
                    SearchOverlay(
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button(action: { webPage.goBack() }) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(!webPage.canGoBack)
                        
                        Button(action: { webPage.goForward() }) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(!webPage.canGoForward)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Button(action: { showSearchOverlay = true }) {
                        HStack {
                            Image(systemName: webPage.url?.scheme == "https" ? "lock.fill" : "lock.open")
                                .foregroundColor(webPage.url?.scheme == "https" ? .green : .orange)
                                .font(.caption)
                            
                            Text(displayURL)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { webPage.reload() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        Button(action: { showWalletSettings = true }) {
                            Image(systemName: "wallet.pass")
                        }
                    }
                }
            }
            .sheet(isPresented: $showWalletSettings) {
                WalletSettingsView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var displayURL: String {
        guard let url = webPage.url else { return "Enter URL" }
        return url.host ?? url.absoluteString
    }
    
    private func loadInitialURL() {
        loadURL("https://app.uniswap.org")
    }
    
    private func loadURL(_ urlString: String) {
        var finalURLString = urlString
        
        // Add scheme if missing
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            finalURLString = "https://\(urlString)"
        }
        
        guard let url = URL(string: finalURLString) else { return }
        webPage.load(URLRequest(url: url))
    }
}

// Simplified WebPage Observable
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

// Simplified Search Overlay
struct SearchOverlay: View {
    @Binding var searchText: String
    @Binding var isVisible: Bool
    let onSelectURL: (String) -> Void
    
    var body: some View {
        VStack {
            HStack {
                TextField("Search or enter URL", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        onSelectURL(searchText)
                    }
                
                Button("Cancel") {
                    isVisible = false
                }
            }
            .padding()
            
            Spacer()
        }
        .background(Color.black.opacity(0.8))
    }
}

// Wallet Settings View
struct WalletSettingsView: View {
    @StateObject private var walletInjector = WalletInjector.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Wallet Provider") {
                    Picker("Provider Type", selection: $walletInjector.selectedProvider) {
                        ForEach(WalletProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Test Account") {
                    TextField("Wallet Address", text: $walletInjector.testAddress)
                        .font(.system(.caption, design: .monospaced))
                    
                    Picker("Chain ID", selection: $walletInjector.chainId) {
                        Text("Ethereum (1)").tag(1)
                        Text("Polygon (137)").tag(137)
                        Text("Arbitrum (42161)").tag(42161)
                        Text("Optimism (10)").tag(10)
                    }
                }
                
                Section("Options") {
                    Toggle("Auto-Connect", isOn: $walletInjector.autoConnect)
                    Toggle("Debug Logging", isOn: $walletInjector.debugLogging)
                }
            }
            .navigationTitle("Wallet Injection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}