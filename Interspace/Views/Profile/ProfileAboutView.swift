import SwiftUI

struct ProfileAboutView: View {
    @Environment(\.dismiss) var dismiss
    
    // App version from Info.plist
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom navigation bar
            HStack {
                Text("About")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Color(white: 0.15))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            List {
                    // Version Section
                    Section {
                        HStack {
                            Text("Version")
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(appVersion) (\(buildNumber))")
                                .foregroundColor(.gray)
                        }
                        .listRowBackground(Color(white: 0.1))
                    }
                    
                    // Support Section
                    Section {
                        // Help & Support
                        Button(action: {
                            // Open help URL
                            if let url = URL(string: "https://interspace.chat/help") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Label("Help & Support", systemImage: "questionmark.circle")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        .listRowBackground(Color(white: 0.1))
                        
                        // Terms & Privacy
                        Button(action: {
                            // Open terms URL
                            if let url = URL(string: "https://interspace.chat/terms") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Label("Terms & Privacy", systemImage: "doc.text")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        .listRowBackground(Color(white: 0.1))
                    }
                    
                    // Additional Info Section
                    Section {
                        // Website
                        Button(action: {
                            if let url = URL(string: "https://interspace.chat") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Label("Website", systemImage: "globe")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        .listRowBackground(Color(white: 0.1))
                        
                        // Twitter/X
                        Button(action: {
                            if let url = URL(string: "https://twitter.com/interspace") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Label("Follow Us", systemImage: "bird.fill")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        .listRowBackground(Color(white: 0.1))
                    }
                    
                    // Credits
                    Section {
                        VStack(spacing: 8) {
                            Text("Built with ❤️ by Interspace")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                            
                            Text("© 2025 Interspace. All rights reserved.")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.7))
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 20)
                        .listRowBackground(Color.clear)
                    }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(Color.black.opacity(0.001))
        .background(Material.ultraThinMaterial)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

struct ProfileAboutView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileAboutView()
            .preferredColorScheme(.dark)
    }
}