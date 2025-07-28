// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Interspace",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        .package(
            url: "https://github.com/reown-com/reown-swift.git",
            .upToNextMajor(from: "1.0.0")
        ),
        .package(
            url: "https://github.com/argentlabs/web3.swift.git",
            .upToNextMajor(from: "1.6.0")
        ),
        .package(
            url: "https://github.com/krzyzanowskim/CryptoSwift.git",
            .upToNextMajor(from: "1.8.0")
        ),
        .package(
            url: "https://github.com/daltoniam/Starscream.git",
            .upToNextMajor(from: "4.0.0")
        ),
        .package(
            url: "https://github.com/essentiaone/HDWallet.git",
            .upToNextMajor(from: "0.3.0")
        )
    ],
    targets: [
        .target(
            name: "Interspace",
            dependencies: [
                .product(name: "ReownAppKit", package: "reown-swift"),
                .product(name: "WalletConnectNetworking", package: "reown-swift"),
                .product(name: "WalletConnectSign", package: "reown-swift"),
                .product(name: "WalletConnectRelay", package: "reown-swift"),
                .product(name: "WalletConnectSigner", package: "reown-swift"),
                .product(name: "Web3", package: "web3.swift"),
                .product(name: "Web3PromiseKit", package: "web3.swift"),
                .product(name: "Web3ContractABI", package: "web3.swift"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "Starscream", package: "Starscream"),
                .product(name: "HDWalletKit", package: "HDWallet")
            ]
        )
    ]
)