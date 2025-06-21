// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Interspace",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        // Google Sign-In
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.1.0"),
        
        // Wallet SDKs
        .package(url: "https://github.com/MetaMask/metamask-ios-sdk", from: "0.8.10"),
        // Temporarily disabled - Coinbase SDK causing crashes
        // .package(url: "https://github.com/MobileWalletProtocol/wallet-mobile-sdk", from: "1.0.3"),
    ],
    targets: [
        .target(
            name: "Interspace",
            dependencies: [
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS"),
                .product(name: "metamask-ios-sdk", package: "metamask-ios-sdk"),
                // Temporarily disabled - Coinbase SDK causing crashes
                // .product(name: "CoinbaseWalletSDK", package: "wallet-mobile-sdk")
            ]
        )
    ]
)