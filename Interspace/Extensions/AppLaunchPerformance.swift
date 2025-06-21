import Foundation
import UIKit

/// Tracks app launch performance metrics
class AppLaunchPerformance {
    static let shared = AppLaunchPerformance()
    
    private var startTime: CFAbsoluteTime
    private var milestones: [(name: String, time: CFAbsoluteTime)] = []
    
    private init() {
        // Get process start time
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
          startTime = CFAbsoluteTimeGetCurrent() - Double(info.system_time.seconds)
        } else {
            startTime = CFAbsoluteTimeGetCurrent()
        }
        
        print("⏱️ App Launch Performance: Process started")
    }
    
    /// Mark when app delegate starts
    func markAppDelegateStart() {
        addMilestone("AppDelegate Start")
    }
    
    /// Mark when app delegate finishes
    func markAppDelegateEnd() {
        addMilestone("AppDelegate End")
    }
    
    /// Mark when first content view appears
    func markFirstContentView() {
        addMilestone("First ContentView")
    }
    
    /// Mark when authentication check completes
    func markAuthenticationCheck() {
        addMilestone("Auth Check Complete")
    }
    
    /// Mark when user data loads
    func markUserDataLoaded() {
        addMilestone("User Data Loaded")
    }
    
    /// Mark when app is fully interactive
    func markAppInteractive() {
        addMilestone("App Interactive")
        generateReport()
    }
    
    /// Add a custom milestone
    func addMilestone(_ name: String) {
        let time = CFAbsoluteTimeGetCurrent()
        milestones.append((name, time))
        
        let elapsed = time - startTime
        print("⏱️ \(name): \(String(format: "%.2f", elapsed))s")
    }
    
    /// Generate performance report
    private func generateReport() {
        print("\n📊 App Launch Performance Report")
        print("================================")
        
        var lastTime = startTime
        for milestone in milestones {
            let totalTime = milestone.time - startTime
            let deltaTime = milestone.time - lastTime
            
            print("• \(milestone.name):")
            print("  Total: \(String(format: "%.3f", totalTime))s")
            print("  Delta: \(String(format: "%.3f", deltaTime))s")
            
            lastTime = milestone.time
        }
        
        if let lastMilestone = milestones.last {
            let totalLaunchTime = lastMilestone.time - startTime
            print("\n🚀 Total Launch Time: \(String(format: "%.3f", totalLaunchTime))s")
            
            // Provide performance assessment
            if totalLaunchTime < 1.0 {
                print("✅ Excellent launch performance!")
            } else if totalLaunchTime < 2.0 {
                print("👍 Good launch performance")
            } else if totalLaunchTime < 3.0 {
                print("⚠️ Launch performance needs improvement")
            } else {
                print("❌ Poor launch performance - optimization needed")
            }
        }
        
        print("================================\n")
    }
    
    /// Reset performance tracking
    func reset() {
        milestones.removeAll()
        startTime = CFAbsoluteTimeGetCurrent()
    }
}
