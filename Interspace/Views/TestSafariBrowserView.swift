import SwiftUI

struct TestSafariBrowserView: View {
    @State private var showBrowser = false
    
    let testApp = BookmarkedApp(
        id: "test",
        name: "The Guardian",
        url: "https://www.theguardian.com",
        iconUrl: nil,
        position: 0,
        folderId: nil
    )
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Safari Browser Test")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                Button(action: {
                    showBrowser = true
                }) {
                    Text("Open Browser")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
        }
        .fullScreenCover(isPresented: $showBrowser) {
            WebBrowserView(app: testApp)
        }
    }
}

#Preview {
    TestSafariBrowserView()
}