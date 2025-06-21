import Foundation

// MARK: - Test Result
struct TestResult: Codable {
    let testName: String
    let category: String
    let success: Bool
    let message: String
    let executionTime: TimeInterval
    let timestamp: Date
    let details: TestDetails?
    let error: TestError?
    
    init(
        testName: String,
        category: String,
        success: Bool,
        message: String,
        executionTime: TimeInterval,
        details: TestDetails? = nil,
        error: TestError? = nil
    ) {
        self.testName = testName
        self.category = category
        self.success = success
        self.message = message
        self.executionTime = executionTime
        self.timestamp = Date()
        self.details = details
        self.error = error
    }
}

// MARK: - Test Details
struct TestDetails: Codable {
    // Request/Response data
    var requestURL: String?
    var requestMethod: String?
    var requestHeaders: [String: String]?
    var requestBody: Data?
    var responseStatusCode: Int?
    var responseHeaders: [String: String]?
    var responseBody: Data?
    
    // Auth specific
    var accountId: String?
    var profileId: String?
    var accessToken: String?
    var refreshToken: String?
    var sessionId: String?
    
    // Timing
    var networkLatency: TimeInterval?
    var processingTime: TimeInterval?
    
    // Additional metadata
    var metadata: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case requestURL, requestMethod, requestHeaders, requestBody
        case responseStatusCode, responseHeaders, responseBody
        case accountId, profileId, accessToken, refreshToken, sessionId
        case networkLatency, processingTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        requestURL = try container.decodeIfPresent(String.self, forKey: .requestURL)
        requestMethod = try container.decodeIfPresent(String.self, forKey: .requestMethod)
        requestHeaders = try container.decodeIfPresent([String: String].self, forKey: .requestHeaders)
        requestBody = try container.decodeIfPresent(Data.self, forKey: .requestBody)
        responseStatusCode = try container.decodeIfPresent(Int.self, forKey: .responseStatusCode)
        responseHeaders = try container.decodeIfPresent([String: String].self, forKey: .responseHeaders)
        responseBody = try container.decodeIfPresent(Data.self, forKey: .responseBody)
        accountId = try container.decodeIfPresent(String.self, forKey: .accountId)
        profileId = try container.decodeIfPresent(String.self, forKey: .profileId)
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        networkLatency = try container.decodeIfPresent(TimeInterval.self, forKey: .networkLatency)
        processingTime = try container.decodeIfPresent(TimeInterval.self, forKey: .processingTime)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(requestURL, forKey: .requestURL)
        try container.encodeIfPresent(requestMethod, forKey: .requestMethod)
        try container.encodeIfPresent(requestHeaders, forKey: .requestHeaders)
        try container.encodeIfPresent(requestBody, forKey: .requestBody)
        try container.encodeIfPresent(responseStatusCode, forKey: .responseStatusCode)
        try container.encodeIfPresent(responseHeaders, forKey: .responseHeaders)
        try container.encodeIfPresent(responseBody, forKey: .responseBody)
        try container.encodeIfPresent(accountId, forKey: .accountId)
        try container.encodeIfPresent(profileId, forKey: .profileId)
        try container.encodeIfPresent(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(networkLatency, forKey: .networkLatency)
        try container.encodeIfPresent(processingTime, forKey: .processingTime)
    }
}

// MARK: - Test Error
struct TestError: Codable, Error {
    let code: String
    let message: String
    let underlyingError: String?
    let stackTrace: [String]?
    
    init(code: String, message: String, underlyingError: Error? = nil) {
        self.code = code
        self.message = message
        self.underlyingError = underlyingError?.localizedDescription
        self.stackTrace = Thread.callStackSymbols
    }
}

// MARK: - Test Report
struct TestReport: Codable {
    let id = UUID()
    let timestamp: Date
    let environment: TestEnvironment
    let configuration: TestConfiguration
    let results: [TestResult]
    let summary: TestSummary
    
    struct TestEnvironment: Codable {
        let device: String
        let osVersion: String
        let appVersion: String
        let buildNumber: String
        let apiVersion: String
        let baseURL: String
    }
    
    struct TestSummary: Codable {
        let totalTests: Int
        let passed: Int
        let failed: Int
        let skipped: Int
        let totalExecutionTime: TimeInterval
        let successRate: Double
    }
}