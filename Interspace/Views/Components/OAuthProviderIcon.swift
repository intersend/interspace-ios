import SwiftUI

struct OAuthProviderIcon: View {
    let provider: String
    let size: CGFloat
    
    @State private var iconImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let iconImage = iconImage {
                Image(uiImage: iconImage)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.5)
            } else {
                // Fallback to system icon
                Image(systemName: iconForProvider(provider))
                    .font(.system(size: size * 0.7))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            loadIcon()
        }
    }
    
    private func loadIcon() {
        // Handle provider name variations
        let iconName = provider == "epicgames" ? "epic_icon" : "\(provider)_icon"
        
        // First try to load from Assets
        if let localImage = UIImage(named: iconName) {
            self.iconImage = localImage
            self.isLoading = false
            return
        }
        
        // If not found locally, try to load from URL
        guard let iconSet = OAuthProviderIconURLs.icons[provider] else {
            self.isLoading = false
            return
        }
        
        // Determine which URL to use based on screen scale
        let scale = UIScreen.main.scale
        let urlString: String
        if scale >= 3 {
            urlString = iconSet.retinaHD
        } else if scale >= 2 {
            urlString = iconSet.retina
        } else {
            urlString = iconSet.standard
        }
        
        guard let url = URL(string: urlString) else {
            self.isLoading = false
            return
        }
        
        // Load image from URL
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.iconImage = image
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }
    
    private func iconForProvider(_ provider: String) -> String {
        switch provider {
        case "apple": return "applelogo"
        case "google": return "g.circle.fill"
        case "discord": return "message.circle.fill"
        case "facebook": return "f.circle.fill"
        case "github": return "chevron.left.forwardslash.chevron.right"
        case "twitter", "x": return "x.circle.fill"
        case "spotify": return "music.note.list"
        case "tiktok": return "music.note"
        case "shopify": return "cart.fill"
        case "epicgames", "epic": return "gamecontroller.fill"
        default: return "person.circle.fill"
        }
    }
}