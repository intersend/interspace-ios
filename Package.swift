// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Interspace",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        .package(url: "https://github.com/WalletConnect/WalletConnectSwiftV2.git", from: "1.9.0")
    ],
    targets: [
        .target(
            name: "Interspace",
            dependencies: [
                .product(name: "WalletConnect", package: "WalletConnectSwiftV2"),
                .product(name: "WalletConnectSign", package: "WalletConnectSwiftV2")
            ]
        )
    ]
)