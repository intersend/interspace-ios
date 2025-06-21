import Foundation
import CoreData
import CryptoKit

// MARK: - Cache Storage Manager

final class CacheStorageManager {
    
    // MARK: - Private Properties
    
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "InterspaceCache")
        
        // Configure for performance
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("❌ Failed to load cache store: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    private let encryptionKey: SymmetricKey
    private let cacheQueue = DispatchQueue(label: "com.interspace.cache.storage", attributes: .concurrent)
    
    // Cache size management
    private let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private var currentCacheSize: Int64 = 0
    
    // MARK: - Initialization
    
    init() {
        // Generate or retrieve encryption key from keychain
        if let keyData = KeychainManager.shared.getCacheEncryptionKey() {
            self.encryptionKey = SymmetricKey(data: keyData)
        } else {
            let key = SymmetricKey(size: .bits256)
            KeychainManager.shared.saveCacheEncryptionKey(key.withUnsafeBytes { Data($0) })
            self.encryptionKey = key
        }
        
        // Calculate initial cache size
        Task {
            await calculateCacheSize()
        }
        
        // Setup cache cleanup
        setupCacheCleanup()
    }
    
    // MARK: - Public Methods
    
    /// Store data in cache with encryption
    func store<T: Codable>(
        _ data: T,
        type: T.Type,
        key: String,
        expiration: TimeInterval
    ) async throws {
        let context = persistentContainer.newBackgroundContext()
        
        try await context.perform {
            // Encode data
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(data)
            
            // Encrypt data
            let encryptedData = try self.encrypt(jsonData)
            
            // Calculate checksum
            let checksum = self.calculateChecksum(jsonData)
            
            // Check if entry exists
            let fetchRequest = CacheEntryEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "key == %@", key)
            
            let existingEntries = try context.fetch(fetchRequest)
            
            let entry: CacheEntryEntity
            if let existing = existingEntries.first {
                entry = existing
            } else {
                entry = CacheEntryEntity(context: context)
                entry.id = UUID().uuidString
                entry.key = key
            }
            
            entry.type = String(describing: type)
            entry.data = encryptedData
            entry.checksum = checksum
            entry.timestamp = Date()
            entry.expirationDate = Date().addingTimeInterval(expiration)
            entry.size = Int64(encryptedData.count)
            
            try context.save()
        }
        
        // Update cache size outside of the context.perform block
        await self.calculateCacheSize()
        
        // Cleanup if needed
        if self.currentCacheSize > self.maxCacheSize {
            await self.performCacheCleanup()
        }
    }
    
    /// Retrieve data from cache with decryption
    func retrieve<T: Codable>(
        type: T.Type,
        key: String
    ) async throws -> T? {
        let context = persistentContainer.viewContext
        
        return try await context.perform {
            let fetchRequest = CacheEntryEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "key == %@ AND type == %@", key, String(describing: type))
            fetchRequest.fetchLimit = 1
            
            guard let entry = try context.fetch(fetchRequest).first else {
                return nil
            }
            
            // Check expiration
            if let expirationDate = entry.expirationDate, expirationDate < Date() {
                // Delete expired entry
                context.delete(entry)
                try? context.save()
                return nil
            }
            
            // Decrypt data
            guard let encryptedData = entry.data else {
                return nil
            }
            let decryptedData = try self.decrypt(encryptedData)
            
            // Verify checksum
            let currentChecksum = self.calculateChecksum(decryptedData)
            guard let storedChecksum = entry.checksum, currentChecksum == storedChecksum else {
                print("⚠️ Cache checksum mismatch for key: \(key)")
                context.delete(entry)
                try? context.save()
                return nil
            }
            
            // Decode data
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: decryptedData)
        }
    }
    
    /// Invalidate cache entries
    func invalidate(type: String? = nil, id: String? = nil) {
        let context = persistentContainer.newBackgroundContext()
        
        context.perform {
            let fetchRequest = CacheEntryEntity.fetchRequest()
            
            if let type = type, let id = id {
                fetchRequest.predicate = NSPredicate(format: "type == %@ AND key CONTAINS %@", type, id)
            } else if let type = type {
                fetchRequest.predicate = NSPredicate(format: "type == %@", type)
            }
            
            do {
                let entries = try context.fetch(fetchRequest)
                entries.forEach { context.delete($0) }
                try context.save()
            } catch {
                print("❌ Failed to invalidate cache: \(error)")
            }
        }
    }
    
    /// Invalidate all cache entries
    func invalidateAll() {
        let context = persistentContainer.newBackgroundContext()
        
        context.perform {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = CacheEntryEntity.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                try context.save()
            } catch {
                print("❌ Failed to clear cache: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        return sealedBox.combined ?? Data()
    }
    
    private func decrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }
    
    private func calculateChecksum(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func calculateCacheSize() async {
        let context = persistentContainer.viewContext
        
        await withCheckedContinuation { continuation in
            context.perform {
                let fetchRequest = CacheEntryEntity.fetchRequest()
                
                do {
                    let entries = try context.fetch(fetchRequest)
                    self.currentCacheSize = entries.reduce(0) { $0 + $1.size }
                } catch {
                    print("❌ Failed to calculate cache size: \(error)")
                }
                continuation.resume()
            }
        }
    }
    
    private func performCacheCleanup() async {
        let context = persistentContainer.newBackgroundContext()
        
        await withCheckedContinuation { continuation in
            context.perform {
                // Delete expired entries first
                let expiredFetchRequest = CacheEntryEntity.fetchRequest()
                expiredFetchRequest.predicate = NSPredicate(format: "expirationDate < %@", Date() as NSDate)
                
                do {
                    let expiredEntries = try context.fetch(expiredFetchRequest)
                    expiredEntries.forEach { context.delete($0) }
                    
                    // If still over limit, delete oldest entries
                    if self.currentCacheSize > self.maxCacheSize {
                        let fetchRequest = CacheEntryEntity.fetchRequest()
                        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
                        
                        let entries = try context.fetch(fetchRequest)
                        var deletedSize: Int64 = 0
                        
                        for entry in entries {
                            if self.currentCacheSize - deletedSize <= self.maxCacheSize * 80 / 100 { // Keep 80% of max
                                break
                            }
                            
                            deletedSize += entry.size
                            context.delete(entry)
                        }
                    }
                    
                    try context.save()
                    continuation.resume()
                    
                } catch {
                    print("❌ Failed to cleanup cache: \(error)")
                    continuation.resume()
                }
            }
        }
        
        // Calculate cache size after cleanup
        await self.calculateCacheSize()
    }
    
    private func setupCacheCleanup() {
        // Cleanup expired entries every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await self.performCacheCleanup()
            }
        }
    }
}

// Note: CacheEntryEntity fetchRequest() is auto-generated by Core Data