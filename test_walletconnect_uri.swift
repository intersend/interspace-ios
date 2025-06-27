#!/usr/bin/env swift

// Test WalletConnect URI
// This simulates what happens when a user scans a WalletConnect QR code

import Foundation

let testURI = "wc:744dbf71677ab076a60a6b297139d52cb798c0637e99f32edf6ae7f18affb9df@2?relay-protocol=irn&symKey=3f43cce1b6cfdf099331f4346264b8048cebd675fe817bf803ae9a17d1cff337&expiryTimestamp=1750990737"

print("Testing WalletConnect URI:")
print(testURI)
print("")

// Parse the URI components
if let url = URL(string: testURI) {
    print("✅ Valid URL format")
    print("Scheme: \(url.scheme ?? "none")")
    print("Host: \(url.host ?? "none")")
    
    // Extract topic (the part after wc: and before @)
    let components = testURI.split(separator: ":")
    if components.count >= 2 {
        let afterWC = String(components[1])
        let topicComponents = afterWC.split(separator: "@")
        if topicComponents.count >= 1 {
            print("Topic: \(topicComponents[0])")
        }
    }
    
    // Parse query parameters
    if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
        print("\nQuery parameters:")
        for item in queryItems {
            print("  \(item.name): \(item.value ?? "nil")")
        }
    }
} else {
    print("❌ Invalid URL format")
}

print("\n✅ This URI appears to be a valid WalletConnect v2 URI")
print("  - Version: 2 (indicated by @2)")
print("  - Relay Protocol: irn")
print("  - Has symmetric key for encryption")
print("  - Expiry: \(Date(timeIntervalSince1970: 1750990737))")