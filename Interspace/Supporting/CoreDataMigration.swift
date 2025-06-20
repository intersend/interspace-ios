import Foundation
import CoreData

// MARK: - Core Data Migration Manager

final class CoreDataMigrationManager {
    
    static func performMigrationIfNeeded() {
        // Check if this is the first launch with Core Data
        let hasPerformedMigration = UserDefaults.standard.bool(forKey: "com.interspace.hasPerformedCoreDataMigration")
        
        if !hasPerformedMigration {
            print("🔄 Performing Core Data migration...")
            
            // Migrate existing UserDefaults cache to Core Data
            migrateUserDefaultsCache()
            
            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: "com.interspace.hasPerformedCoreDataMigration")
            
            print("✅ Core Data migration completed")
        }
    }
    
    private static func migrateUserDefaultsCache() {
        let userDefaults = UserDefaults.standard
        let cacheManager = CacheStorageManager()
        
        // Migrate user cache
        if let userData = userDefaults.data(forKey: "com.interspace.user.cache") {
            do {
                let user = try JSONDecoder().decode(User.self, from: userData)
                Task {
                    try? await cacheManager.store(
                        user,
                        type: User.self,
                        key: "users/me",
                        expiration: 14400 // 4 hours
                    )
                }
            } catch {
                print("Failed to migrate user cache: \(error)")
            }
        }
        
        // Migrate profiles cache
        if let profilesData = userDefaults.data(forKey: "com.interspace.profiles.cache") {
            do {
                let profiles = try JSONDecoder().decode([SmartProfile].self, from: profilesData)
                Task {
                    try? await cacheManager.store(
                        profiles,
                        type: [SmartProfile].self,
                        key: "profiles",
                        expiration: 14400 // 4 hours
                    )
                }
            } catch {
                print("Failed to migrate profiles cache: \(error)")
            }
        }
        
        // Clean up old cache after migration
        userDefaults.removeObject(forKey: "com.interspace.user.cache")
        userDefaults.removeObject(forKey: "com.interspace.profiles.cache")
        userDefaults.removeObject(forKey: "com.interspace.activeProfile.cache")
        userDefaults.removeObject(forKey: "com.interspace.authState.cache")
    }
}