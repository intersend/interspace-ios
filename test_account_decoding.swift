import Foundation

// Test AccountV2 model
struct AccountV2: Codable {
    let id: String
    let type: String?  // Backend uses 'type'
    let strategy: String?  // For compatibility
    let identifier: String
    let metadata: [String: String]?
    let verified: Bool?
    let createdAt: String?
    let updatedAt: String?
    
    // Computed property to get the account type
    var accountType: String {
        return type ?? strategy ?? "unknown"
    }
}

// Test decoding the actual backend response
let jsonString = """
{
    "id": "cmcat7xq80007p342rqpycht8",
    "type": "email",
    "identifier": "arda@test2.com",
    "verified": false
}
"""

let decoder = JSONDecoder()
if let jsonData = jsonString.data(using: .utf8) {
    do {
        let account = try decoder.decode(AccountV2.self, from: jsonData)
        print("✅ Successfully decoded account:")
        print("  ID: \(account.id)")
        print("  Type: \(account.type ?? "nil")")
        print("  Strategy: \(account.strategy ?? "nil")")
        print("  Account Type: \(account.accountType)")
        print("  Identifier: \(account.identifier)")
        print("  Verified: \(account.verified ?? false)")
    } catch {
        print("❌ Decoding failed: \(error)")
    }
}