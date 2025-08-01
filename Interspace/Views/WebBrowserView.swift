import SwiftUI
import WebKit
import UIKit

// MARK: - Web Browser View
@available(iOS 15.0, *)
struct WebBrowserView: View {
    let app: BookmarkedApp
    
    var body: some View {
        if #available(iOS 17.0, *) {
            NativeWebBrowserView(app: app)
        } else {
            // Fallback for older iOS versions
            LegacyWebBrowserView(app: app)
        }
    }
}

// MARK: - Legacy Web Browser View (iOS 15-16)
@available(iOS 15.0, *)
struct LegacyWebBrowserView: View {
    let app: BookmarkedApp
    @Environment(\.dismiss) private var dismiss
    @StateObject private var webPage: WebPage
    @State private var showAddedConfirmation = false
    
    init(app: BookmarkedApp) {
        self.app = app
        self._webPage = StateObject(wrappedValue: WebPage.from(app: app))
    }
    
    var body: some View {
        ZStack {
            // WebView
            WebView(webPage: webPage)
                .ignoresSafeArea()
            
            // Simple navigation bar
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    if let host = webPage.url?.host {
                        Text(host)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button(action: { addAppToCurrentProfile() }) {
                            Label("Add to Apps", systemImage: "plus.app")
                        }
                        
                        Button(action: { shareCurrentPage() }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 50)
                .background(Color.black.opacity(0.9))
                
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
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
    
    private func loadInitialURL() {
        guard let url = URL(string: app.url) else { return }
        let request = URLRequest(url: url)
        webPage.load(request)
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
    
    private func addAppToCurrentProfile() {
        Task {
            do {
                // Get the active profile ID from somewhere (you may need to adjust this based on your app's state management)
                guard let activeProfileId = UserDefaults.standard.string(forKey: "activeProfileId") else {
                    print("No active profile ID found")
                    return
                }
                
                let request = CreateAppRequest(
                    name: app.name,
                    url: app.url,
                    iconUrl: app.iconUrl,
                    folderId: nil,
                    position: 0
                )
                
                _ = try await ProfileAPI.shared.createApp(profileId: activeProfileId, request: request)
                showAddedConfirmation = true
                
                // Use UIKit's feedback generator
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            } catch {
                print("Failed to add app: \(error)")
            }
        }
    }
}