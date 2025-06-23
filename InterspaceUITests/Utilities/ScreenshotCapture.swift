import XCTest

// MARK: - Screenshot Capture Utility

class ScreenshotCapture {
    
    private let testCase: XCTestCase
    private var screenshotCounter = 0
    
    init(testCase: XCTestCase) {
        self.testCase = testCase
    }
    
    // MARK: - Screenshot Methods
    
    func captureScreen(named name: String? = nil, description: String? = nil) {
        screenshotCounter += 1
        
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        
        // Set name
        if let name = name {
            attachment.name = "\(screenshotCounter)_\(name)"
        } else {
            attachment.name = "Screenshot_\(screenshotCounter)"
        }
        
        // Set description
        if let description = description {
            attachment.userInfo = ["description": description]
        }
        
        // Configure lifetime
        attachment.lifetime = .keepAlways
        
        testCase.add(attachment)
    }
    
    func captureElement(_ element: XCUIElement, named name: String? = nil) {
        screenshotCounter += 1
        
        let screenshot = element.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        
        if let name = name {
            attachment.name = "\(screenshotCounter)_Element_\(name)"
        } else {
            attachment.name = "Element_Screenshot_\(screenshotCounter)"
        }
        
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
    }
    
    func captureFailure(error: Error? = nil, file: String = #file, line: Int = #line) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        
        attachment.name = "Failure_\(file.split(separator: "/").last ?? "Unknown")_Line\(line)"
        
        if let error = error {
            attachment.userInfo = ["error": error.localizedDescription]
        }
        
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
    }
    
    // MARK: - Flow Documentation
    
    func documentFlow(named flowName: String, steps: () throws -> Void) rethrows {
        captureScreen(named: "\(flowName)_Start", description: "Beginning of \(flowName)")
        
        do {
            try steps()
            captureScreen(named: "\(flowName)_Complete", description: "Successful completion of \(flowName)")
        } catch {
            captureFailure(error: error)
            throw error
        }
    }
    
    func documentStep(_ stepName: String, action: () throws -> Void) rethrows {
        captureScreen(named: "Before_\(stepName)")
        try action()
        captureScreen(named: "After_\(stepName)")
    }
    
    // MARK: - Comparison Screenshots
    
    func captureForComparison(identifier: String, element: XCUIElement? = nil) {
        let screenshot = element?.screenshot() ?? XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        
        attachment.name = "Comparison_\(identifier)_\(Date().timeIntervalSince1970)"
        attachment.lifetime = .keepAlways
        attachment.userInfo = ["comparison_id": identifier]
        
        testCase.add(attachment)
    }
    
    // MARK: - State Documentation
    
    func documentAppState(description: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        
        attachment.name = "AppState_\(Date().timeIntervalSince1970)"
        attachment.userInfo = [
            "description": description,
            "timestamp": Date().description
        ]
        attachment.lifetime = .keepAlways
        
        testCase.add(attachment)
    }
}

// MARK: - Screenshot Configuration

struct ScreenshotConfiguration {
    var captureOnFailure: Bool = true
    var captureKeySteps: Bool = true
    var captureTransitions: Bool = false
    var compressionQuality: CGFloat = 0.8
    
    static let `default` = ScreenshotConfiguration()
    
    static let detailed = ScreenshotConfiguration(
        captureOnFailure: true,
        captureKeySteps: true,
        captureTransitions: true,
        compressionQuality: 1.0
    )
    
    static let minimal = ScreenshotConfiguration(
        captureOnFailure: true,
        captureKeySteps: false,
        captureTransitions: false,
        compressionQuality: 0.5
    )
}

// MARK: - XCTestCase Extension

extension XCTestCase {
    
    private struct AssociatedKeys {
        static var screenshotCapture = "screenshotCapture"
        static var screenshotConfig = "screenshotConfig"
    }
    
    var screenshots: ScreenshotCapture {
        if let capture = objc_getAssociatedObject(self, &AssociatedKeys.screenshotCapture) as? ScreenshotCapture {
            return capture
        }
        
        let capture = ScreenshotCapture(testCase: self)
        objc_setAssociatedObject(self, &AssociatedKeys.screenshotCapture, capture, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return capture
    }
    
    var screenshotConfig: ScreenshotConfiguration {
        get {
            if let config = objc_getAssociatedObject(self, &AssociatedKeys.screenshotConfig) as? ScreenshotConfiguration {
                return config
            }
            return .default
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.screenshotConfig, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func captureScreenshotOnFailure() {
        if screenshotConfig.captureOnFailure {
            screenshots.captureFailure()
        }
    }
}

// MARK: - Visual Testing Helpers

class VisualTestingHelper {
    
    static func compareScreenshots(current: XCUIScreenshot, reference: XCUIScreenshot, tolerance: CGFloat = 0.01) -> Bool {
        // This is a placeholder for visual comparison logic
        // In a real implementation, you would compare pixel data
        return true
    }
    
    static func saveReferenceScreenshot(_ screenshot: XCUIScreenshot, identifier: String) {
        // Save screenshot as reference for future comparisons
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Reference_\(identifier)"
        attachment.lifetime = .keepAlways
    }
}

// MARK: - Screenshot Annotations

struct ScreenshotAnnotation {
    let text: String
    let position: CGPoint
    let color: UIColor
    
    static func annotate(screenshot: XCUIScreenshot, with annotations: [ScreenshotAnnotation]) -> XCUIScreenshot {
        // This would require image processing to add text overlays
        // Placeholder for annotation logic
        return screenshot
    }
}