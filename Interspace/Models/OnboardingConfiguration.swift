import UIKit
import UIOnboarding

struct OnboardingConfiguration {
    
    static func setUp() -> UIOnboardingViewConfiguration {
        return .init(
            appIcon: setUpIcon(),
            firstTitleLine: setUpFirstTitleLine(),
            secondTitleLine: setUpSecondTitleLine(),
            features: setUpFeatures(),
            textViewConfiguration: setUpNotice(),
            buttonConfiguration: setUpButton()
        )
    }
    
    static func setUpIcon() -> UIImage {
        return UIImage(named: "SplashScreenLogo") ?? UIImage(systemName: "sparkles")!
    }
    
    static func setUpFirstTitleLine() -> NSMutableAttributedString {
        return .init(
            string: "Welcome to",
            attributes: [
                .font: UIFont.systemFont(ofSize: 36, weight: .light),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
    }
    
    static func setUpSecondTitleLine() -> NSMutableAttributedString {
        return .init(
            string: "Interspace",
            attributes: [
                .font: UIFont.systemFont(ofSize: 42, weight: .bold),
                .foregroundColor: UIColor.label
            ]
        )
    }
    
    static func setUpFeatures() -> Array<UIOnboardingFeature> {
        return [
            .init(
                icon: UIImage(systemName: "person.crop.circle.fill")!
                    .withRenderingMode(.alwaysOriginal)
                    .withTintColor(UIColor.systemBlue),
                title: "Universal Identity",
                description: "Your digital presence, unified"
            ),
            .init(
                icon: UIImage(systemName: "link.circle.fill")!
                    .withRenderingMode(.alwaysOriginal)
                    .withTintColor(UIColor.systemPurple),
                title: "Connect Everything",
                description: "Wallets, social accounts, apps in one place"
            ),
            .init(
                icon: UIImage(systemName: "lock.shield.fill")!
                    .withRenderingMode(.alwaysOriginal)
                    .withTintColor(UIColor.systemGreen),
                title: "Stay Secure",
                description: "End-to-end encryption protects your data"
            )
        ]
    }
    
    static func setUpNotice() -> UIOnboardingTextViewConfiguration {
        return .init(
            icon: UIImage(systemName: "info.circle.fill")!
                .withRenderingMode(.alwaysOriginal)
                .withTintColor(UIColor.secondaryLabel),
            text: "By continuing, you agree to our Terms of Service",
            linkTitle: "Terms of Service",
            fontName: "",
            fontWeight: .regular,
            link: "https://interspace.so/terms",
            linkColor: UIColor.secondaryLabel,
            iconColor: UIColor.secondaryLabel
        )
    }
    
    static func setUpButton() -> UIOnboardingButtonConfiguration {
        return .init(
            title: "Continue",
            titleColor: UIColor.white,
            backgroundColor: UIColor.systemBlue
        )
    }
}
