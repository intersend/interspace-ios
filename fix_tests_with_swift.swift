#!/usr/bin/env swift

// Swift script to fix test configuration by generating proper xcodeproj entries
// This can be run without additional dependencies

import Foundation

let projectPath = "Interspace.xcodeproj/project.pbxproj"
let testFiles = [
    "InterspaceTests/InterspaceTests.swift",
    "InterspaceTests/TestConfiguration.swift",
    "InterspaceTests/Models/AuthModelsTests.swift",
    "InterspaceTests/Services/APIServiceTests.swift",
    "InterspaceTests/Services/AuthenticationManagerTests.swift",
    "InterspaceTests/Services/GoogleAuthenticationTests.swift",
    "InterspaceTests/Services/SessionCoordinatorTests.swift",
    "InterspaceTests/ViewModels/AuthViewModelTests.swift",
    "InterspaceTests/IntegrationTests/AuthenticationFlowTests.swift",
    "InterspaceTests/IntegrationTests/AuthServiceIntegrationTests.swift",
    "InterspaceTests/IntegrationTests/ProfileViewModelIntegrationTests.swift",
    "InterspaceTests/Mocks/MockAPIService.swift",
    "InterspaceTests/Mocks/MockKeychainManager.swift",
    "InterspaceTests/Utilities/TestHelpers.swift",
    "InterspaceTests/V2APITests/V2APITests.swift",
    "InterspaceTests/V2APITests/V2APITestRunner.swift"
]

// Generate UUIDs for new file references
func generateUUID() -> String {
    return UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24).uppercased()
}

// Read the current project file
guard let projectData = try? String(contentsOfFile: projectPath, encoding: .utf8) else {
    print("❌ Error: Could not read project file")
    exit(1)
}

// Create backup
let backupPath = projectPath + ".backup.\(Date().timeIntervalSince1970)"
try? projectData.write(toFile: backupPath, atomically: true, encoding: .utf8)
print("📋 Created backup at: \(backupPath)")

// Generate the file reference entries
var fileRefs: [String] = []
var buildFileRefs: [String] = []
var fileUUIDs: [String: String] = [:]

for file in testFiles {
    let uuid = generateUUID()
    let buildUUID = generateUUID()
    let fileName = URL(fileURLWithPath: file).lastPathComponent
    
    fileUUIDs[file] = uuid
    
    // Create PBXFileReference entry
    let fileRef = "\t\t\(uuid) /* \(fileName) */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \(fileName); sourceTree = \"<group>\"; };"
    fileRefs.append(fileRef)
    
    // Create PBXBuildFile entry
    let buildRef = "\t\t\(buildUUID) /* \(fileName) in Sources */ = {isa = PBXBuildFile; fileRef = \(uuid) /* \(fileName) */; };"
    buildFileRefs.append(buildRef)
}

print("📝 Generated \(fileRefs.count) file references")

// Output the changes needed
print("\n⚠️  Manual steps required:")
print("1. Open \(projectPath) in a text editor")
print("2. Add the following entries to the appropriate sections:")
print("\n/* Begin PBXFileReference section */")
print("Add these lines:")
fileRefs.forEach { print($0) }

print("\n/* Begin PBXBuildFile section */")
print("Add these lines:")
buildFileRefs.forEach { print($0) }

print("\n3. In the Sources build phase for InterspaceTests (ID: 8E12DBE5DC3FA45B8CBEAC7F)")
print("   Replace the empty files = ( ); with:")
print("   files = (")
buildFileRefs.forEach { ref in
    let uuid = ref.split(separator: " ").first!.trimmingCharacters(in: .whitespaces)
    print("      \(uuid),")
}
print("   );")

print("\n4. Save the file and run tests")

// Create an xcodebuild test script
let testScript = """
#!/bin/bash
# Test runner script
set -e

echo "🧪 Running iOS Tests"
echo "==================="

# Check if workspace exists
if [ -f "Interspace.xcworkspace/contents.xcworkspacedata" ]; then
    BUILD_ROOT="-workspace Interspace.xcworkspace"
else
    BUILD_ROOT="-project Interspace.xcodeproj"
fi

# Build and test
xcodebuild $BUILD_ROOT \\
    -scheme Interspace \\
    -destination "platform=iOS Simulator,name=iPhone 15,OS=17.5" \\
    -configuration Debug \\
    test \\
    -only-testing:InterspaceTests \\
    CODE_SIGNING_ALLOWED=NO
"""

try? testScript.write(toFile: "test_runner.sh", atomically: true, encoding: .utf8)
// Make it executable
let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/chmod")
process.arguments = ["+x", "test_runner.sh"]
try? process.run()
process.waitUntilExit()

print("\n✅ Created test_runner.sh")
print("\n🎯 Quick test: ./test_runner.sh")