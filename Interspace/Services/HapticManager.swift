import UIKit

// MARK: - Haptic Manager
// Centralized haptic feedback management

final class HapticManager {
    
    // Singleton
    static let shared = HapticManager()
    
    // Haptic generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    
    private init() {
        // Prepare generators
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactSoft.prepare()
        impactRigid.prepare()
        selection.prepare()
        notification.prepare()
    }
    
    // MARK: - Impact Feedback
    
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        shared.impact(style: style)
    }
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            impactLight.impactOccurred()
        case .medium:
            impactMedium.impactOccurred()
        case .heavy:
            impactHeavy.impactOccurred()
        case .soft:
            impactSoft.impactOccurred()
        case .rigid:
            impactRigid.impactOccurred()
        @unknown default:
            impactMedium.impactOccurred()
        }
    }
    
    // MARK: - Selection Feedback
    
    static func selection() {
        shared.selection.selectionChanged()
    }
    
    // MARK: - Notification Feedback
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        shared.notification.notificationOccurred(type)
    }
}