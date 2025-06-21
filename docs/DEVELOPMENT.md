# Development Guide

This guide provides detailed instructions for setting up and developing the Interspace iOS application.

## Table of Contents

1. [Environment Setup](#environment-setup)
2. [Project Configuration](#project-configuration)
3. [Development Workflow](#development-workflow)
4. [API Integration](#api-integration)
5. [Testing](#testing)
6. [Debugging](#debugging)
7. [Performance Optimization](#performance-optimization)
8. [Troubleshooting](#troubleshooting)

## Environment Setup

### Prerequisites

1. **macOS**: Version 13.0 (Ventura) or later
2. **Xcode**: Version 15.0 or later
   ```bash
   # Check Xcode version
   xcodebuild -version
   ```
3. **Command Line Tools**:
   ```bash
   xcode-select --install
   ```
4. **CocoaPods**:
   ```bash
   sudo gem install cocoapods
   pod --version  # Should be 1.12.0+
   ```

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/interspace/interspace-ios.git
   cd interspace-ios
   ```

2. **Install dependencies**:
   ```bash
   pod install
   ```

3. **Copy configuration templates**:
   ```bash
   # Create configuration files from templates
   cp Interspace/Supporting/BuildConfiguration.xcconfig.template Interspace/Supporting/BuildConfiguration.xcconfig
   cp Interspace/GoogleService-Info.plist.template Interspace/GoogleService-Info.plist
   cp .env.example .env
   cp .xcode.env.local.template .xcode.env.local
   ```

## Project Configuration

### API Keys Setup

1. **Google OAuth Configuration**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing
   - Enable Google Sign-In API
   - Create OAuth 2.0 credentials (iOS)
   - Add your bundle identifier
   - Download configuration and update `GoogleService-Info.plist`

2. **Infura Configuration**:
   - Sign up at [Infura](https://infura.io/)
   - Create a new project
   - Copy the Project ID
   - Add to `BuildConfiguration.xcconfig`:
     ```
     INFURA_API_KEY = your_infura_project_id_here
     ```

3. **WalletConnect Configuration**:
   - Register at [WalletConnect Cloud](https://cloud.walletconnect.com/)
   - Create a new project
   - Copy the Project ID
   - Add to `BuildConfiguration.xcconfig`:
     ```
     WALLETCONNECT_PROJECT_ID = your_walletconnect_project_id_here
     ```

### Build Configurations

The project supports three build configurations:

1. **Debug**: For local development
   - API URLs point to local/development servers
   - Debug logging enabled
   - Assertions active

2. **Staging**: For testing
   - API URLs point to staging servers
   - Limited logging
   - Performance monitoring

3. **Release**: For production
   - API URLs point to production servers
   - Minimal logging
   - Optimizations enabled

### Environment Variables

Edit `.xcode.env.local` with your local configuration:

```bash
# Node.js path (if using React Native bridges)
export NODE_BINARY=/usr/local/bin/node

# API Keys
export INFURA_API_KEY=your_infura_key_here
export WALLETCONNECT_PROJECT_ID=your_walletconnect_id_here

# API URLs
export API_BASE_URL_DEBUG=http://localhost:3000/api/v1
export API_BASE_URL_RELEASE=https://api.interspace.com/api/v1
```

## Development Workflow

### Code Organization

```
Interspace/
├── Models/           # Data models and business logic
├── Views/            # SwiftUI views
├── ViewModels/       # View models (MVVM pattern)
├── Services/         # API and business services
├── Extensions/       # Swift extensions
├── Components/       # Reusable UI components
└── Supporting/       # Configuration and resources
```

### Creating New Features

1. **Create the model** (if needed):
   ```swift
   // Models/Feature.swift
   struct Feature: Codable, Identifiable {
       let id: String
       let name: String
       // ... properties
   }
   ```

2. **Create the service**:
   ```swift
   // Services/FeatureService.swift
   class FeatureService {
       func fetchFeatures() async throws -> [Feature] {
           // Implementation
       }
   }
   ```

3. **Create the view model**:
   ```swift
   // ViewModels/FeatureViewModel.swift
   @MainActor
   class FeatureViewModel: ObservableObject {
       @Published var features: [Feature] = []
       @Published var isLoading = false
       
       private let service = FeatureService()
       
       func loadFeatures() async {
           isLoading = true
           defer { isLoading = false }
           
           do {
               features = try await service.fetchFeatures()
           } catch {
               // Handle error
           }
       }
   }
   ```

4. **Create the view**:
   ```swift
   // Views/FeatureView.swift
   struct FeatureView: View {
       @StateObject private var viewModel = FeatureViewModel()
       
       var body: some View {
           // View implementation
       }
   }
   ```

### SwiftUI Best Practices

1. **View Composition**:
   ```swift
   struct ContentView: View {
       var body: some View {
           VStack {
               HeaderView()
               MainContent()
               FooterView()
           }
       }
   }
   ```

2. **State Management**:
   ```swift
   // Local state
   @State private var isPresented = false
   
   // Observed object
   @ObservedObject var viewModel: MyViewModel
   
   // Environment object
   @EnvironmentObject var session: SessionManager
   ```

3. **Modifiers**:
   ```swift
   Text("Hello")
       .font(.headline)
       .foregroundColor(.primary)
       .padding()
       .background(Color.secondary.opacity(0.1))
       .cornerRadius(8)
   ```

## API Integration

### Making API Requests

1. **Using APIService**:
   ```swift
   let response: MyResponse = try await APIService.shared.request(
       endpoint: "endpoint/path",
       method: .POST,
       body: myRequestBody
   )
   ```

2. **Error Handling**:
   ```swift
   do {
       let data = try await apiService.fetchData()
       // Handle success
   } catch APIError.unauthorized {
       // Handle unauthorized
   } catch APIError.networkError {
       // Handle network error
   } catch {
       // Handle other errors
   }
   ```

### Authentication Flow

1. **Login**:
   ```swift
   try await AuthService.shared.login(
       email: email,
       password: password
   )
   ```

2. **Token Management**:
   - Tokens are automatically stored in Keychain
   - Automatic token refresh on 401 responses
   - Token included in all authenticated requests

## Testing

### Unit Tests

1. **Create test file**:
   ```swift
   // InterspaceTests/FeatureTests.swift
   import XCTest
   @testable import Interspace
   
   final class FeatureTests: XCTestCase {
       func testFeatureCreation() {
           let feature = Feature(id: "1", name: "Test")
           XCTAssertEqual(feature.name, "Test")
       }
   }
   ```

2. **Run tests**:
   ```bash
   # Command line
   xcodebuild test -workspace Interspace.xcworkspace -scheme Interspace
   
   # Or in Xcode
   Cmd+U
   ```

### UI Tests

1. **Create UI test**:
   ```swift
   // InterspaceUITests/FeatureUITests.swift
   func testFeatureFlow() {
       let app = XCUIApplication()
       app.launch()
       
       // Test implementation
   }
   ```

### Test Data

Use the `DevelopmentWalletService` for testing wallet functionality without real blockchain connections.

## Debugging

### Debug Tools

1. **SwiftUI Preview**:
   ```swift
   struct ContentView_Previews: PreviewProvider {
       static var previews: some View {
           ContentView()
               .previewDevice("iPhone 15 Pro")
               .preferredColorScheme(.dark)
       }
   }
   ```

2. **Debug Overlay**:
   - Enable in Settings → Developer Options
   - Shows environment, API calls, and performance metrics

3. **Network Debugging**:
   ```swift
   // Enable in AppDelegate
   URLSession.shared.configuration.waitsForConnectivity = true
   ```

### Logging

```swift
// Use built-in logging
print("🔍 Debug: \(message)")
print("⚠️ Warning: \(message)")
print("❌ Error: \(error)")

// Or use os_log for production
import os.log
let logger = Logger(subsystem: "com.interspace", category: "Feature")
logger.debug("Debug message")
```

## Performance Optimization

### Image Optimization

1. **Use AsyncImage for remote images**:
   ```swift
   AsyncImage(url: URL(string: imageURL)) { image in
       image
           .resizable()
           .aspectRatio(contentMode: .fit)
   } placeholder: {
       ProgressView()
   }
   ```

2. **Cache images**:
   ```swift
   // Images are automatically cached by URLSession
   ```

### List Performance

1. **Use LazyVStack/LazyVGrid**:
   ```swift
   ScrollView {
       LazyVStack {
           ForEach(items) { item in
               ItemView(item: item)
           }
       }
   }
   ```

2. **Implement proper Identifiable**:
   ```swift
   struct Item: Identifiable {
       let id = UUID()  // Stable identifier
   }
   ```

## Troubleshooting

### Common Issues

1. **Pod Installation Fails**:
   ```bash
   # Clean and reinstall
   pod deintegrate
   pod install
   ```

2. **Build Errors**:
   ```bash
   # Clean build folder
   rm -rf ~/Library/Developer/Xcode/DerivedData
   # Or in Xcode: Shift+Cmd+K
   ```

3. **Simulator Issues**:
   - Reset simulator: Device → Erase All Content and Settings
   - Try different simulator device

4. **Signing Issues**:
   - Ensure valid Apple Developer account
   - Check bundle identifier matches
   - Update provisioning profiles

### Debug Tips

1. **API Response Issues**:
   - Check network logs in console
   - Verify API endpoint URLs
   - Check authentication tokens

2. **UI Layout Issues**:
   - Use SwiftUI Inspector (Cmd+Click on view)
   - Check constraint warnings
   - Test on different device sizes

3. **Performance Issues**:
   - Use Instruments for profiling
   - Check for retain cycles
   - Optimize image loading

## Resources

- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Apple Developer Forums](https://developer.apple.com/forums/)
- [Our Discord Community](https://discord.gg/interspace)