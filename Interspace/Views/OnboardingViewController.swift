import UIKit
import UIOnboarding

class OnboardingViewController: UIViewController {
    
    var onContinue: (() -> Void)?
    private var onboardingController: UIOnboardingViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create the onboarding view controller
        onboardingController = UIOnboardingViewController(withConfiguration: OnboardingConfiguration.setUp())
        onboardingController.delegate = self
        
        // Set dark mode to match app theme
        overrideUserInterfaceStyle = .dark
        onboardingController.overrideUserInterfaceStyle = .dark
        
        // Add as child view controller
        addChild(onboardingController)
        view.addSubview(onboardingController.view)
        onboardingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            onboardingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            onboardingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            onboardingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            onboardingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        onboardingController.didMove(toParent: self)
    }
}

// MARK: - UIOnboardingViewControllerDelegate

extension OnboardingViewController: UIOnboardingViewControllerDelegate {
    
    func didFinishOnboarding(onboardingViewController: UIOnboardingViewController) {
        // Trigger haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        
        // Call the completion handler
        onContinue?()
    }
}