import Foundation

// MARK: - Accessibility Identifiers

enum AccessibilityIdentifiers {
    
    // MARK: - Authentication
    enum Authentication {
        static let welcomeTitle = "auth.welcome.title"
        static let connectWalletButton = "auth.connect.wallet"
        static let emailButton = "auth.continue.email"
        static let googleButton = "auth.continue.google"
        static let appleButton = "auth.continue.apple"
        static let guestButton = "auth.continue.guest"
        static let emailTextField = "auth.email.textfield"
        static let sendCodeButton = "auth.send.code"
        static let verificationCodeField = "auth.verification.code"
        static let verifyButton = "auth.verify.button"
        static let resendCodeButton = "auth.resend.code"
        static let backButton = "auth.back.button"
    }
    
    // MARK: - Wallet Connection
    enum Wallet {
        static let selectionTray = "wallet.selection.tray"
        static let metamaskButton = "wallet.metamask"
        static let coinbaseButton = "wallet.coinbase"
        static let walletConnectButton = "wallet.walletconnect"
        static let connectingIndicator = "wallet.connecting.indicator"
        static let connectedStatus = "wallet.connected.status"
        static let addressLabel = "wallet.address.label"
        static let disconnectButton = "wallet.disconnect"
        static let transactionHistory = "wallet.transactions"
        static let sendTokenButton = "wallet.send.token"
    }
    
    // MARK: - Profile
    enum Profile {
        static let profileTab = "tab.profile"
        static let profileSwitcher = "profile.switcher"
        static let profileList = "profile.list"
        static let profileCell = "profile.cell"
        static let createProfileButton = "profile.create"
        static let profileNameField = "profile.name.field"
        static let profileIconPicker = "profile.icon.picker"
        static let profileColorPicker = "profile.color.picker"
        static let profileSettings = "profile.settings"
        static let editProfileButton = "profile.edit"
        static let deleteProfileButton = "profile.delete"
        static let profileActiveIndicator = "profile.active.indicator"
        static let linkedAccountsList = "profile.linked.accounts"
        static let addAccountButton = "profile.add.account"
    }
    
    // MARK: - Navigation
    enum Navigation {
        static let tabBar = "navigation.tabbar"
        static let homeTab = "tab.home"
        static let appsTab = "tab.apps"
        static let walletTab = "tab.wallet"
        static let backButton = "navigation.back"
        static let closeButton = "navigation.close"
        static let settingsButton = "navigation.settings"
    }
    
    // MARK: - Apps
    enum Apps {
        static let appGrid = "apps.grid"
        static let appCell = "apps.cell"
        static let addAppButton = "apps.add"
        static let searchBar = "apps.search"
        static let categoryFilter = "apps.category.filter"
        static let appDetailView = "apps.detail"
        static let removeAppButton = "apps.remove"
        static let appWebView = "apps.webview"
        static let appFolder = "apps.folder"
        static let createFolderButton = "apps.create.folder"
    }
    
    // MARK: - Settings
    enum Settings {
        static let settingsView = "settings.view"
        static let developerSection = "settings.developer"
        static let privacySection = "settings.privacy"
        static let securitySection = "settings.security"
        static let notificationsToggle = "settings.notifications"
        static let biometricsToggle = "settings.biometrics"
        static let darkModeToggle = "settings.darkmode"
        static let languageSelector = "settings.language"
        static let aboutButton = "settings.about"
        static let logoutButton = "settings.logout"
        static let deleteAccountButton = "settings.delete.account"
    }
    
    // MARK: - Transaction
    enum Transaction {
        static let historyList = "transaction.history"
        static let transactionCell = "transaction.cell"
        static let transactionDetail = "transaction.detail"
        static let sendButton = "transaction.send"
        static let receiveButton = "transaction.receive"
        static let amountField = "transaction.amount"
        static let recipientField = "transaction.recipient"
        static let gasSelector = "transaction.gas"
        static let confirmButton = "transaction.confirm"
        static let statusIndicator = "transaction.status"
    }
    
    // MARK: - Onboarding
    enum Onboarding {
        static let skipButton = "onboarding.skip"
        static let nextButton = "onboarding.next"
        static let getStartedButton = "onboarding.get.started"
        static let pageIndicator = "onboarding.page.indicator"
        static let featureTitle = "onboarding.feature.title"
        static let featureDescription = "onboarding.feature.description"
    }
    
    // MARK: - Common Elements
    enum Common {
        static let loadingIndicator = "common.loading"
        static let errorAlert = "common.error.alert"
        static let successMessage = "common.success.message"
        static let retryButton = "common.retry"
        static let cancelButton = "common.cancel"
        static let confirmButton = "common.confirm"
        static let doneButton = "common.done"
        static let searchBar = "common.search"
        static let refreshControl = "common.refresh"
        static let emptyStateView = "common.empty.state"
    }
    
    // MARK: - Development Mode
    enum DevelopmentMode {
        static let indicator = "dev.mode.indicator"
        static let toggle = "dev.mode.toggle"
        static let testHubButton = "dev.test.hub"
        static let mockDataButton = "dev.mock.data"
        static let networkLogger = "dev.network.logger"
        static let performanceMonitor = "dev.performance.monitor"
    }
}

// MARK: - Accessibility Labels

struct AccessibilityLabels {
    
    // MARK: - Authentication Labels
    struct Authentication {
        static let welcomeTitle = "Welcome to Interspace"
        static let connectWallet = "Connect Wallet"
        static let continueWithEmail = "Continue with Email"
        static let continueWithGoogle = "Continue with Google"
        static let continueWithApple = "Continue with Apple"
        static let continueAsGuest = "Continue as Guest"
        static let emailPlaceholder = "Enter your email"
        static let verificationCodePlaceholder = "Enter 6-digit code"
    }
    
    // MARK: - Profile Labels
    struct Profile {
        static let profileSwitcher = "Switch Profile"
        static let createProfile = "Create New Profile"
        static let editProfile = "Edit Profile"
        static let deleteProfile = "Delete Profile"
        static let profileSettings = "Profile Settings"
        static let linkedAccounts = "Linked Accounts"
        static let addAccount = "Add Account"
    }
    
    // MARK: - Navigation Labels
    struct Navigation {
        static let home = "Home"
        static let apps = "Apps"
        static let wallet = "Wallet"
        static let profile = "Profile"
        static let back = "Back"
        static let close = "Close"
        static let settings = "Settings"
    }
}

// MARK: - Accessibility Hints

struct AccessibilityHints {
    
    struct Authentication {
        static let connectWallet = "Double tap to connect your cryptocurrency wallet"
        static let emailButton = "Double tap to sign in with email"
        static let googleButton = "Double tap to sign in with Google"
        static let appleButton = "Double tap to sign in with Apple"
        static let guestButton = "Double tap to continue without signing in"
    }
    
    struct Profile {
        static let profileSwitcher = "Double tap to view and switch between profiles"
        static let createProfile = "Double tap to create a new profile"
        static let profileCell = "Double tap to switch to this profile"
    }
    
    struct Wallet {
        static let sendToken = "Double tap to send cryptocurrency"
        static let transactionCell = "Double tap to view transaction details"
    }
}