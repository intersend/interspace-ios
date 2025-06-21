import Foundation
import os.log

// MARK: - Test Logger
class TestLogger {
    static let shared = TestLogger()
    
    private let logger = Logger(subsystem: "com.interspace.testhub", category: "TestExecution")
    private var logEntries: [LogEntry] = []
    private let logQueue = DispatchQueue(label: "com.interspace.testhub.logger", attributes: .concurrent)
    
    struct LogEntry: Codable {
        let timestamp: Date
        let level: LogLevel
        let category: String
        let message: String
        let metadata: [String: String]?
        
        var formattedMessage: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            let timeString = formatter.string(from: timestamp)
            
            let levelEmoji: String
            switch level {
            case .debug: levelEmoji = "🔍"
            case .info: levelEmoji = "ℹ️"
            case .warning: levelEmoji = "⚠️"
            case .error: levelEmoji = "❌"
            case .success: levelEmoji = "✅"
            }
            
            return "\(timeString) \(levelEmoji) [\(category)] \(message)"
        }
    }
    
    enum LogLevel: String, Codable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case success = "SUCCESS"
    }
    
    // MARK: - Logging Methods
    
    func debug(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        log(level: .debug, message: message, category: category, metadata: metadata)
        logger.debug("\(message)")
    }
    
    func info(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        log(level: .info, message: message, category: category, metadata: metadata)
        logger.info("\(message)")
    }
    
    func warning(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        log(level: .warning, message: message, category: category, metadata: metadata)
        logger.warning("\(message)")
    }
    
    func error(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        log(level: .error, message: message, category: category, metadata: metadata)
        logger.error("\(message)")
    }
    
    func success(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        log(level: .success, message: message, category: category, metadata: metadata)
        logger.info("✅ \(message)")
    }
    
    // MARK: - Test Specific Logging
    
    func logTestStart(_ testName: String) {
        info("Starting test: \(testName)", category: "TestExecution")
    }
    
    func logTestComplete(_ testName: String, success: Bool, duration: TimeInterval) {
        let message = "Test '\(testName)' completed in \(String(format: "%.2f", duration))s"
        if success {
            success(message, category: "TestExecution")
        } else {
            error(message, category: "TestExecution")
        }
    }
    
    func logNetworkRequest(method: String, url: String, headers: [String: String]? = nil) {
        var metadata: [String: String] = [
            "method": method,
            "url": url
        ]
        
        if let headers = headers {
            metadata["headers"] = headers.description
        }
        
        debug("Network request: \(method) \(url)", category: "Network", metadata: metadata)
    }
    
    func logNetworkResponse(statusCode: Int, url: String, duration: TimeInterval) {
        let metadata: [String: String] = [
            "statusCode": "\(statusCode)",
            "url": url,
            "duration": "\(String(format: "%.3f", duration))s"
        ]
        
        let level: LogLevel = statusCode >= 200 && statusCode < 300 ? .info : .warning
        log(
            level: level,
            message: "Network response: \(statusCode) from \(url)",
            category: "Network",
            metadata: metadata
        )
    }
    
    // MARK: - Log Management
    
    private func log(level: LogLevel, message: String, category: String, metadata: [String: String]?) {
        logQueue.async(flags: .barrier) {
            let entry = LogEntry(
                timestamp: Date(),
                level: level,
                category: category,
                message: message,
                metadata: metadata
            )
            self.logEntries.append(entry)
            
            // Keep only last 1000 entries
            if self.logEntries.count > 1000 {
                self.logEntries.removeFirst()
            }
        }
    }
    
    func getAllLogs() -> [LogEntry] {
        logQueue.sync {
            return logEntries
        }
    }
    
    func getLogsForCategory(_ category: String) -> [LogEntry] {
        logQueue.sync {
            return logEntries.filter { $0.category == category }
        }
    }
    
    func clearLogs() {
        logQueue.async(flags: .barrier) {
            self.logEntries.removeAll()
        }
    }
    
    // MARK: - Export
    
    func exportLogs() -> Data? {
        let logs = getAllLogs()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            return try encoder.encode(logs)
        } catch {
            logger.error("Failed to export logs: \(error.localizedDescription)")
            return nil
        }
    }
    
    func exportLogsAsText() -> String {
        let logs = getAllLogs()
        return logs.map { $0.formattedMessage }.joined(separator: "\n")
    }
}

// MARK: - Network Request Logger
extension TestLogger {
    func logAPICall(
        endpoint: String,
        method: String,
        parameters: [String: Any]? = nil,
        response: Data? = nil,
        statusCode: Int? = nil,
        error: Error? = nil,
        duration: TimeInterval
    ) {
        var metadata: [String: String] = [
            "endpoint": endpoint,
            "method": method,
            "duration": "\(String(format: "%.3f", duration))s"
        ]
        
        if let parameters = parameters {
            metadata["parameters"] = String(describing: parameters)
        }
        
        if let statusCode = statusCode {
            metadata["statusCode"] = "\(statusCode)"
        }
        
        if let error = error {
            metadata["error"] = error.localizedDescription
        }
        
        if let response = response,
           let jsonObject = try? JSONSerialization.jsonObject(with: response),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            metadata["response"] = prettyString
        }
        
        let level: LogLevel = error != nil ? .error : .info
        log(
            level: level,
            message: "API call: \(method) \(endpoint)",
            category: "API",
            metadata: metadata
        )
    }
}