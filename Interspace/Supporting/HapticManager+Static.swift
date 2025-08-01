import UIKit

// MARK: - HapticManager Static Extensions
// Convenience static methods for haptic feedback

extension HapticManager {
    
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        shared.impact(style: style)
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        shared.notification(type: type)
    }
    
    static func selection() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
}