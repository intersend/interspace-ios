import Foundation
import UIKit

// MARK: - Test Reporter
class TestReporter {
    static let shared = TestReporter()
    
    private let fileManager = FileManager.default
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
    
    private var reportsDirectory: URL? {
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsPath.appendingPathComponent("TestReports")
    }
    
    init() {
        createReportsDirectory()
    }
    
    // MARK: - Directory Management
    
    private func createReportsDirectory() {
        guard let reportsDir = reportsDirectory else { return }
        
        if !fileManager.fileExists(atPath: reportsDir.path) {
            try? fileManager.createDirectory(at: reportsDir, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Report Generation
    
    func generateReport(
        configuration: TestConfiguration,
        results: [TestResult],
        duration: TimeInterval
    ) -> TestReport {
        let environment = TestReport.TestEnvironment(
            device: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            apiVersion: configuration.apiVersion,
            baseURL: configuration.baseURL
        )
        
        let passed = results.filter { $0.success }.count
        let failed = results.filter { !$0.success }.count
        let totalTests = results.count
        let successRate = totalTests > 0 ? Double(passed) / Double(totalTests) : 0.0
        
        let summary = TestReport.TestSummary(
            totalTests: totalTests,
            passed: passed,
            failed: failed,
            skipped: 0,
            totalExecutionTime: duration,
            successRate: successRate
        )
        
        return TestReport(
            timestamp: Date(),
            environment: environment,
            configuration: configuration,
            results: results,
            summary: summary
        )
    }
    
    // MARK: - Report Saving
    
    func saveReport(_ report: TestReport) -> URL? {
        guard let reportsDir = reportsDirectory else { return nil }
        
        let fileName = "TestReport_\(dateFormatter.string(from: report.timestamp)).json"
        let fileURL = reportsDir.appendingPathComponent(fileName)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(report)
            try data.write(to: fileURL)
            TestLogger.shared.success("Report saved to: \(fileName)", category: "Reporter")
            return fileURL
        } catch {
            TestLogger.shared.error("Failed to save report: \(error.localizedDescription)", category: "Reporter")
            return nil
        }
    }
    
    // MARK: - Report Export
    
    func exportReportAsCSV(_ report: TestReport) -> Data? {
        var csvString = "Test Name,Category,Success,Execution Time,Message,Error\n"
        
        for result in report.results {
            let row = [
                result.testName,
                result.category,
                result.success ? "Pass" : "Fail",
                String(format: "%.3f", result.executionTime),
                result.message,
                result.error?.message ?? ""
            ]
            
            let csvRow = row.map { field in
                // Escape quotes and wrap in quotes if contains comma or newline
                let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                return field.contains(",") || field.contains("\n") ? "\"\(escaped)\"" : escaped
            }.joined(separator: ",")
            
            csvString += csvRow + "\n"
        }
        
        // Add summary
        csvString += "\nSummary\n"
        csvString += "Total Tests,\(report.summary.totalTests)\n"
        csvString += "Passed,\(report.summary.passed)\n"
        csvString += "Failed,\(report.summary.failed)\n"
        csvString += "Success Rate,\(String(format: "%.1f%%", report.summary.successRate * 100))\n"
        csvString += "Total Time,\(String(format: "%.2fs", report.summary.totalExecutionTime))\n"
        
        return csvString.data(using: .utf8)
    }
    
    func exportReportAsHTML(_ report: TestReport) -> Data? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Interspace Test Report</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; }
                h1, h2 { color: #333; }
                .summary { background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0; }
                .pass { color: #4CAF50; font-weight: bold; }
                .fail { color: #F44336; font-weight: bold; }
                table { border-collapse: collapse; width: 100%; margin: 20px 0; }
                th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
                th { background-color: #f2f2f2; }
                tr:nth-child(even) { background-color: #f9f9f9; }
                .error { background-color: #ffebee; }
                .success { background-color: #e8f5e9; }
            </style>
        </head>
        <body>
            <h1>Interspace V2 API Test Report</h1>
            <p>Generated: \(dateFormatter.string(from: report.timestamp))</p>
            
            <div class="summary">
                <h2>Summary</h2>
                <p>Environment: \(report.environment.device) - iOS \(report.environment.osVersion)</p>
                <p>API Version: \(report.environment.apiVersion)</p>
                <p>Base URL: \(report.environment.baseURL)</p>
                <p>Total Tests: \(report.summary.totalTests)</p>
                <p>Passed: <span class="pass">\(report.summary.passed)</span></p>
                <p>Failed: <span class="fail">\(report.summary.failed)</span></p>
                <p>Success Rate: \(String(format: "%.1f%%", report.summary.successRate * 100))</p>
                <p>Total Execution Time: \(String(format: "%.2fs", report.summary.totalExecutionTime))</p>
            </div>
            
            <h2>Test Results</h2>
            <table>
                <tr>
                    <th>Test Name</th>
                    <th>Category</th>
                    <th>Result</th>
                    <th>Time</th>
                    <th>Message</th>
                </tr>
        """
        
        for result in report.results {
            let rowClass = result.success ? "success" : "error"
            let resultText = result.success ? "<span class='pass'>PASS</span>" : "<span class='fail'>FAIL</span>"
            
            html += """
                <tr class="\(rowClass)">
                    <td>\(result.testName)</td>
                    <td>\(result.category)</td>
                    <td>\(resultText)</td>
                    <td>\(String(format: "%.3fs", result.executionTime))</td>
                    <td>\(result.message)</td>
                </tr>
            """
        }
        
        html += """
            </table>
        </body>
        </html>
        """
        
        return html.data(using: .utf8)
    }
    
    // MARK: - Report Management
    
    func getAllReports() -> [URL] {
        guard let reportsDir = reportsDirectory else { return [] }
        
        do {
            let files = try fileManager.contentsOfDirectory(
                at: reportsDir,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            
            return files
                .filter { $0.pathExtension == "json" }
                .sorted { url1, url2 in
                    let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    return date1! > date2!
                }
        } catch {
            TestLogger.shared.error("Failed to list reports: \(error.localizedDescription)", category: "Reporter")
            return []
        }
    }
    
    func loadReport(from url: URL) -> TestReport? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(TestReport.self, from: data)
        } catch {
            TestLogger.shared.error("Failed to load report: \(error.localizedDescription)", category: "Reporter")
            return nil
        }
    }
    
    func deleteReport(at url: URL) {
        do {
            try fileManager.removeItem(at: url)
            TestLogger.shared.info("Deleted report: \(url.lastPathComponent)", category: "Reporter")
        } catch {
            TestLogger.shared.error("Failed to delete report: \(error.localizedDescription)", category: "Reporter")
        }
    }
    
    func deleteAllReports() {
        let reports = getAllReports()
        for report in reports {
            deleteReport(at: report)
        }
    }
}