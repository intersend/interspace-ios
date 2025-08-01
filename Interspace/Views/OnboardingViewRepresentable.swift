import SwiftUI
import UIOnboarding

struct OnboardingViewRepresentable: UIViewControllerRepresentable {
    let onContinue: () -> Void
    
    func makeUIViewController(context: Context) -> OnboardingViewController {
        let controller = OnboardingViewController()
        controller.onContinue = onContinue
        return controller
    }
    
    func updateUIViewController(_ uiViewController: OnboardingViewController, context: Context) {
        // No updates needed
    }
}