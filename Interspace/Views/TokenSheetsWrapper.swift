import SwiftUI

// MARK: - Token Sheets Configuration
// This file configures which token sheet implementations to use throughout the app
// The enhanced sheets include polished animations and improved UX

// Configuration flag to switch between base and enhanced implementations
let useEnhancedTokenSheets = true

// Helper function to determine which implementation to use
func tokenSheetConfiguration() -> (useEnhanced: Bool) {
    return (useEnhanced: useEnhancedTokenSheets)
}