import SwiftUI

struct TestView: View {
    var body: some View {
        // Test 1: Simple TabView with explicit ignoring safe area
        TabView {
            Color.red
                .ignoresSafeArea()
                .overlay(Text("Tab 1").foregroundColor(.white))
                .tabItem { Label("Red", systemImage: "1.circle") }
            
            Color.blue
                .ignoresSafeArea()
                .overlay(Text("Tab 2").foregroundColor(.white))
                .tabItem { Label("Blue", systemImage: "2.circle") }
        }
        .ignoresSafeArea()
        .background(Color.green.ignoresSafeArea()) // Should NOT be visible if TabView fills screen
    }
}

struct TestView2: View {
    var body: some View {
        // Test 2: Simple colored rectangle
        Color.yellow
            .overlay(Text("Should fill entire screen").foregroundColor(.black))
    }
}

#Preview {
    TestView()
}