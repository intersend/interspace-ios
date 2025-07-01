import UIKit

// Simplified app delegate for tests that bypasses the SwiftUI app initialization
@objc(TestAppDelegate)
class TestAppDelegate: NSObject, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Minimal initialization for tests
        print("Test app delegate started")
        
        // Don't initialize services - tests will do this as needed
        return true
    }
}