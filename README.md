# Interspace iOS

<p align="center">
  <img src="docs/images/app-icon.png" alt="Interspace Logo" width="120" height="120">
</p>

<p align="center">
  <a href="https://developer.apple.com/swift/">
    <img src="https://img.shields.io/badge/Swift-5.9-orange.svg" alt="Swift 5.9">
  </a>
  <a href="https://developer.apple.com/xcode/">
    <img src="https://img.shields.io/badge/Xcode-15.0+-blue.svg" alt="Xcode 15.0+">
  </a>
  <a href="https://developer.apple.com/documentation/ios-ipados-release-notes">
    <img src="https://img.shields.io/badge/iOS-16.0+-green.svg" alt="iOS 16.0+">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT">
  </a>
</p>

Interspace is an open-source iOS application that provides a secure, privacy-first platform for managing digital identities, social profiles, and cryptocurrency wallets. Built with SwiftUI and modern iOS development practices.

## ✨ Features

- 🆔 **Multi-Profile Management**: Create and manage multiple digital identities
- 🔐 **Privacy-First Design**: Your data stays on your device
- 👛 **Wallet Integration**: Connect MetaMask, Coinbase Wallet, and more
- 🌐 **Social Account Linking**: Connect Twitter, Discord, Instagram, and other platforms
- 🔑 **Secure Authentication**: Support for email, Google Sign-In, Apple Sign-In, and Passkeys
- 🎨 **Beautiful UI**: Modern SwiftUI interface with smooth animations
- 🌓 **Dark Mode Support**: Fully adaptive to system appearance
- 🔒 **End-to-End Security**: Military-grade encryption and security practices

## 📋 Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- iOS 16.0+ deployment target
- CocoaPods 1.12.0+ (for dependency management)
- Active Apple Developer account (for device testing)

### Required API Keys

To run the app, you'll need to obtain the following API keys:

1. **Google OAuth**: [Google Cloud Console](https://console.cloud.google.com/)
2. **Infura**: [Infura Dashboard](https://infura.io/)
3. **WalletConnect**: [WalletConnect Cloud](https://cloud.walletconnect.com/)

## 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/interspace-ios.git
   cd interspace-ios
   ```

2. **Install dependencies**
   ```bash
   pod install
   ```

3. **Configure the project**
   ```bash
   # Copy configuration templates
   cp Interspace/Supporting/BuildConfiguration.xcconfig.template Interspace/Supporting/BuildConfiguration.xcconfig
   cp Interspace/GoogleService-Info.plist.template Interspace/GoogleService-Info.plist
   cp .env.example .env
   cp .xcode.env.local.template .xcode.env.local
   ```

4. **Add your API keys**
   - Edit `BuildConfiguration.xcconfig` with your API keys
   - Update `GoogleService-Info.plist` with your Firebase configuration
   - Configure `.env` with your environment variables

5. **Open the project**
   ```bash
   open Interspace.xcworkspace
   ```

6. **Select your development team**
   - Open project settings in Xcode
   - Select your development team under "Signing & Capabilities"

7. **Build and run**
   - Select your target device or simulator
   - Press `Cmd+R` to build and run

## 📖 Documentation

- [Architecture Overview](docs/ARCHITECTURE.md) - System design and architecture
- [Development Guide](docs/DEVELOPMENT.md) - Detailed development setup
- [API Documentation](docs/API.md) - Backend API integration
- [Deployment Guide](docs/DEPLOYMENT.md) - Release and deployment process
- [Security Policy](SECURITY.md) - Security practices and vulnerability reporting

## 🏗️ Project Structure

```
interspace-ios/
├── Interspace/              # Main application code
│   ├── Models/             # Data models
│   ├── Views/              # SwiftUI views
│   ├── ViewModels/         # View models (MVVM)
│   ├── Services/           # Business logic and API services
│   ├── Extensions/         # Swift extensions
│   ├── Supporting/         # Supporting files (Info.plist, etc.)
│   └── Assets.xcassets/    # Images and colors
├── InterspaceTests/        # Unit tests
├── InterspaceUITests/      # UI tests
├── docs/                   # Documentation
├── scripts/                # Build and utility scripts
└── Pods/                   # CocoaPods dependencies (git-ignored)
```

## 🧪 Testing

Run the test suite:

```bash
# Unit tests
xcodebuild test -workspace Interspace.xcworkspace -scheme Interspace -destination 'platform=iOS Simulator,name=iPhone 15'

# UI tests
xcodebuild test -workspace Interspace.xcworkspace -scheme InterspaceUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint for code consistency
- Write unit tests for new features
- Update documentation as needed

## 🔒 Security

Security is our top priority. Please review our [Security Policy](SECURITY.md) for:

- Vulnerability reporting procedures
- Security best practices
- Responsible disclosure policy

**Never commit sensitive information like API keys or passwords to the repository.**

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Apple's modern UI framework
- [WalletConnect](https://walletconnect.com/) - Open protocol for wallet connections
- [Google Sign-In](https://developers.google.com/identity) - Authentication services
- All our amazing contributors and the open-source community

## 📬 Contact

- **Issues**: [GitHub Issues](https://github.com/yourusername/interspace-ios/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/interspace-ios/discussions)
- **Email**: support@interspace.app

---

<p align="center">Made with ❤️ by the Interspace Team</p>