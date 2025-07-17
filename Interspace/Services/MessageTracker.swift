import Foundation

/// Tracks processed messages to prevent duplicate handling
actor MessageTracker {
    private var processedMessages = Set<String>()
    private let maxEntries = 1000
    private let cleanupThreshold = 800
    
    /// Check if a message should be processed
    func shouldProcess(_ messageId: String) -> Bool {
        if processedMessages.contains(messageId) {
            return false
        }
        
        // Add to processed set
        processedMessages.insert(messageId)
        
        // Cleanup old entries if needed
        if processedMessages.count > maxEntries {
            cleanupOldEntries()
        }
        
        return true
    }
    
    /// Clean up old entries to prevent memory growth
    private func cleanupOldEntries() {
        // Keep only the most recent entries
        let entriesToRemove = processedMessages.count - cleanupThreshold
        if entriesToRemove > 0 {
            // Remove oldest entries (simple approach)
            processedMessages.removeFirst(entriesToRemove)
        }
    }
    
    /// Clear all tracked messages
    func clear() {
        processedMessages.removeAll()
    }
}