import Foundation

// MARK: - Command Line Test Runner
@main
class TestHubCommand {
    static func main() async {
        print("🚀 Interspace V2 API Test Suite")
        print("================================")
        
        let runner = TestHubCommandRunner()
        
        do {
            // Parse command line arguments
            let arguments = CommandLine.arguments
            let config = try parseConfiguration(from: arguments)
            
            // Run tests
            let results = try await runner.runTests(with: config)
            
            // Generate report
            let report = runner.generateReport(results: results)
            
            // Output results
            printResults(report)
            
            // Exit with appropriate code
            exit(report.allPassed ? 0 : 1)
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    static func parseConfiguration(from arguments: [String]) throws -> TestHubConfiguration {
        var config = TestHubConfiguration()
        
        var i = 1
        while i < arguments.count {
            switch arguments[i] {
            case "--env", "-e":
                i += 1
                guard i < arguments.count else {
                    throw TestHubError.missingArgument("environment")
                }
                config.environment = arguments[i]
                
            case "--category", "-c":
                i += 1
                guard i < arguments.count else {
                    throw TestHubError.missingArgument("category")
                }
                config.category = arguments[i]
                
            case "--output", "-o":
                i += 1
                guard i < arguments.count else {
                    throw TestHubError.missingArgument("output")
                }
                config.outputFormat = arguments[i]
                
            case "--verbose", "-v":
                config.verbose = true
                
            case "--help", "-h":
                printHelp()
                exit(0)
                
            default:
                throw TestHubError.unknownArgument(arguments[i])
            }
            i += 1
        }
        
        return config
    }
    
    static func printHelp() {
        print("""
        Usage: test-hub [OPTIONS]
        
        Options:
          -e, --env <environment>     Set environment (dev, staging, prod) [default: dev]
          -c, --category <category>   Run specific category (auth, profile, linking, token, edge)
          -o, --output <format>       Output format (console, json, junit) [default: console]
          -v, --verbose              Enable verbose logging
          -h, --help                 Show this help message
        
        Examples:
          test-hub                           # Run all tests against dev
          test-hub -e prod                   # Run all tests against production
          test-hub -c auth -v                # Run auth tests with verbose logging
          test-hub -o junit > results.xml    # Output JUnit XML format
        """)
    }
    
    static func printResults(_ report: TestReport) {
        switch report.outputFormat {
        case "json":
            printJSONReport(report)
        case "junit":
            printJUnitReport(report)
        default:
            printConsoleReport(report)
        }
    }
    
    static func printConsoleReport(_ report: TestReport) {
        print("\n📊 Test Results")
        print("================")
        print("Environment: \(report.environment)")
        print("Total Tests: \(report.totalTests)")
        print("Passed: ✅ \(report.passed)")
        print("Failed: ❌ \(report.failed)")
        print("Success Rate: \(String(format: "%.1f%%", report.successRate * 100))")
        print("Duration: \(String(format: "%.2fs", report.duration))")
        
        if !report.failedTests.isEmpty {
            print("\n❌ Failed Tests:")
            for test in report.failedTests {
                print("  - \(test.name): \(test.error)")
            }
        }
        
        print("\n✅ Test run completed!")
    }
    
    static func printJSONReport(_ report: TestReport) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if let data = try? encoder.encode(report),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }
    
    static func printJUnitReport(_ report: TestReport) {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuites name="Interspace V2 API Tests" tests="\(report.totalTests)" failures="\(report.failed)" time="\(report.duration)">
          <testsuite name="V2 API" tests="\(report.totalTests)" failures="\(report.failed)" time="\(report.duration)">
        \(report.allTests.map { test in
            if test.passed {
                return "    <testcase name=\"\(test.name)\" classname=\"\(test.category)\" time=\"\(test.duration)\"/>"
            } else {
                return """
                    <testcase name="\(test.name)" classname="\(test.category)" time="\(test.duration)">
                      <failure message="\(test.error.escapeXML())" type="AssertionError"/>
                    </testcase>
                """
            }
        }.joined(separator: "\n"))
          </testsuite>
        </testsuites>
        """
        print(xml)
    }
}

// MARK: - Test Hub Configuration
struct TestHubConfiguration {
    var environment: String = "dev"
    var category: String? = nil
    var outputFormat: String = "console"
    var verbose: Bool = false
    
    var baseURL: String {
        switch environment {
        case "prod", "production":
            return "https://api.interspace.fi"
        case "staging":
            return "https://api-staging.interspace.fi"
        default:
            return "http://localhost:3000"
        }
    }
    
    var apiVersion: String {
        return "v2"
    }
}

// MARK: - Test Report
struct TestReport: Codable {
    let environment: String
    let totalTests: Int
    let passed: Int
    let failed: Int
    let successRate: Double
    let duration: Double
    let outputFormat: String
    let allTests: [TestResult]
    
    var allPassed: Bool {
        failed == 0
    }
    
    var failedTests: [TestResult] {
        allTests.filter { !$0.passed }
    }
    
    struct TestResult: Codable {
        let name: String
        let category: String
        let passed: Bool
        let duration: Double
        let error: String
    }
}

// MARK: - Errors
enum TestHubError: LocalizedError {
    case missingArgument(String)
    case unknownArgument(String)
    case configurationError(String)
    case testExecutionError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingArgument(let arg):
            return "Missing required argument for: \(arg)"
        case .unknownArgument(let arg):
            return "Unknown argument: \(arg)"
        case .configurationError(let msg):
            return "Configuration error: \(msg)"
        case .testExecutionError(let msg):
            return "Test execution error: \(msg)"
        }
    }
}

// MARK: - String Extensions
extension String {
    func escapeXML() -> String {
        return self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - Command Runner
class TestHubCommandRunner {
    private let startTime = Date()
    
    func runTests(with config: TestHubConfiguration) async throws -> [TestReport.TestResult] {
        var results: [TestReport.TestResult] = []
        
        // Initialize test services
        let testSuite = V2APITestSuite(configuration: config)
        
        // Get tests to run
        let tests: [TestCase]
        if let category = config.category {
            tests = testSuite.getTestsForCategory(category)
        } else {
            tests = testSuite.getAllTests()
        }
        
        // Run each test
        for test in tests {
            if config.verbose {
                print("🧪 Running: \(test.name)")
            }
            
            let testStart = Date()
            do {
                try await test.execute()
                let duration = Date().timeIntervalSince(testStart)
                
                results.append(TestReport.TestResult(
                    name: test.name,
                    category: test.category,
                    passed: true,
                    duration: duration,
                    error: ""
                ))
                
                if config.verbose {
                    print("  ✅ Passed (\(String(format: "%.2fs", duration)))")
                }
                
            } catch {
                let duration = Date().timeIntervalSince(testStart)
                
                results.append(TestReport.TestResult(
                    name: test.name,
                    category: test.category,
                    passed: false,
                    duration: duration,
                    error: error.localizedDescription
                ))
                
                if config.verbose {
                    print("  ❌ Failed: \(error.localizedDescription)")
                }
            }
        }
        
        return results
    }
    
    func generateReport(results: [TestReport.TestResult]) -> TestReport {
        let passed = results.filter { $0.passed }.count
        let failed = results.filter { !$0.passed }.count
        let total = results.count
        let successRate = total > 0 ? Double(passed) / Double(total) : 0.0
        let duration = Date().timeIntervalSince(startTime)
        
        return TestReport(
            environment: "dev",
            totalTests: total,
            passed: passed,
            failed: failed,
            successRate: successRate,
            duration: duration,
            outputFormat: "console",
            allTests: results
        )
    }
}