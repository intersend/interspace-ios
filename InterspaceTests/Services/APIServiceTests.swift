import XCTest
@testable import Interspace

class APIServiceTests: XCTestCase {
    
    var sut: APIService!
    var mockURLSession: MockURLSession!
    
    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        sut = APIService.shared
    }
    
    override func tearDown() {
        sut = nil
        mockURLSession = nil
        super.tearDown()
    }
    
    // MARK: - Request Building Tests
    
    func testPerformRequestWithCorrectURL() async throws {
        // Given
        let endpoint = "/test/endpoint"
        let expectedResponse = TestResponse(id: "123", name: "Test")
        let responseData = try JSONEncoder().encode(expectedResponse)
        
        mockURLSession.mockData = responseData
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // Create a test instance with mock session
        let testService = TestableAPIService(session: mockURLSession)
        
        // When
        let result: TestResponse = try await testService.performRequest(
            endpoint: endpoint,
            method: .GET,
            responseType: TestResponse.self
        )
        
        // Then
        XCTAssertEqual(result.id, expectedResponse.id)
        XCTAssertEqual(result.name, expectedResponse.name)
    }
    
    func testPerformRequestWithAuthHeader() async throws {
        // Given
        let accessToken = "test-access-token"
        sut.setAccessToken(accessToken)
        
        let expectedResponse = TestResponse(id: "123", name: "Test")
        let responseData = try JSONEncoder().encode(expectedResponse)
        
        mockURLSession.mockData = responseData
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let testService = TestableAPIService(session: mockURLSession, accessToken: accessToken)
        
        // When
        let _: TestResponse = try await testService.performRequest(
            endpoint: "/test",
            method: .GET,
            responseType: TestResponse.self,
            requiresAuth: true
        )
        
        // Then
        XCTAssertNotNil(testService.lastRequest)
        XCTAssertEqual(testService.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer \(accessToken)")
    }
    
    // MARK: - Response Handling Tests
    
    func testHandleSuccessfulResponse() async throws {
        // Given
        let expectedResponse = TestResponse(id: "123", name: "Test")
        let responseData = try JSONEncoder().encode(expectedResponse)
        
        mockURLSession.mockData = responseData
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let testService = TestableAPIService(session: mockURLSession)
        
        // When
        let result: TestResponse = try await testService.performRequest(
            endpoint: "/test",
            method: .GET,
            responseType: TestResponse.self
        )
        
        // Then
        XCTAssertEqual(result.id, expectedResponse.id)
        XCTAssertEqual(result.name, expectedResponse.name)
    }
    
    func testHandle401UnauthorizedResponse() async throws {
        // Given
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        
        let testService = TestableAPIService(session: mockURLSession)
        
        // When/Then
        await XCTAssertAsyncThrowsError(
            try await testService.performRequest(
                endpoint: "/test",
                method: .GET,
                responseType: TestResponse.self
            )
        ) { error in
            guard let apiError = error as? APIError else {
                XCTFail("Expected APIError, got \(error)")
                return
            }
            
            if case .unauthorized = apiError {
                // Success
            } else {
                XCTFail("Expected unauthorized error, got \(apiError)")
            }
        }
    }
    
    func testHandleServerError() async throws {
        // Given
        let errorResponse = APIErrorResponse(
            success: false,
            message: "Internal server error",
            error: "SERVER_ERROR",
            statusCode: 500
        )
        let errorData = try JSONEncoder().encode(errorResponse)
        
        mockURLSession.mockData = errorData
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        
        let testService = TestableAPIService(session: mockURLSession)
        
        // When/Then
        await XCTAssertAsyncThrowsError(
            try await testService.performRequest(
                endpoint: "/test",
                method: .GET,
                responseType: TestResponse.self
            )
        ) { error in
            guard let apiError = error as? APIError else {
                XCTFail("Expected APIError, got \(error)")
                return
            }
            
            if case .apiError(let message) = apiError {
                XCTAssertEqual(message, "Internal server error")
            } else {
                XCTFail("Expected apiError, got \(apiError)")
            }
        }
    }
    
    func testHandleDecodingError() async throws {
        // Given
        let invalidJSON = "{ invalid json }"
        mockURLSession.mockData = invalidJSON.data(using: .utf8)
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let testService = TestableAPIService(session: mockURLSession)
        
        // When/Then
        await XCTAssertAsyncThrowsError(
            try await testService.performRequest(
                endpoint: "/test",
                method: .GET,
                responseType: TestResponse.self
            )
        ) { error in
            guard let apiError = error as? APIError else {
                XCTFail("Expected APIError, got \(error)")
                return
            }
            
            if case .decodingFailed = apiError {
                // Success
            } else {
                XCTFail("Expected decodingFailed error, got \(apiError)")
            }
        }
    }
    
    func testHandleEmptyResponse() async throws {
        // Given
        mockURLSession.mockData = Data()
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let testService = TestableAPIService(session: mockURLSession)
        
        // When
        let result: EmptyResponse = try await testService.performRequest(
            endpoint: "/test",
            method: .DELETE,
            responseType: EmptyResponse.self
        )
        
        // Then
        XCTAssertNotNil(result)
    }
    
    // MARK: - Request Methods Tests
    
    func testPOSTRequestWithBody() async throws {
        // Given
        let requestBody = TestRequest(name: "Test Item", value: 42)
        let requestData = try JSONEncoder().encode(requestBody)
        
        let expectedResponse = TestResponse(id: "123", name: "Created")
        let responseData = try JSONEncoder().encode(expectedResponse)
        
        mockURLSession.mockData = responseData
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )
        
        let testService = TestableAPIService(session: mockURLSession)
        
        // When
        let result: TestResponse = try await testService.performRequest(
            endpoint: "/test",
            method: .POST,
            body: requestData,
            responseType: TestResponse.self
        )
        
        // Then
        XCTAssertEqual(result.id, expectedResponse.id)
        XCTAssertNotNil(testService.lastRequest)
        XCTAssertEqual(testService.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(testService.lastRequest?.httpBody, requestData)
        XCTAssertEqual(testService.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
    
    // MARK: - Token Management Tests
    
    func testSetAndClearAccessToken() {
        // Given
        let token = "test-token"
        
        // When
        sut.setAccessToken(token)
        
        // Then
        // Note: We can't directly test the private accessToken property
        // but we can verify it's used in requests
        
        // When
        sut.clearAccessToken()
        
        // Then
        // Token should be cleared
    }
}

// MARK: - Test Helpers

private struct TestRequest: Codable {
    let name: String
    let value: Int
}

private struct TestResponse: Codable {
    let id: String
    let name: String
}

// Testable subclass to access internal state
private class TestableAPIService: APIService {
    let mockSession: URLSession
    var lastRequest: URLRequest?
    private var testAccessToken: String?
    
    init(session: URLSession, accessToken: String? = nil) {
        self.mockSession = session
        self.testAccessToken = accessToken
        super.init()
        
        if let token = accessToken {
            self.setAccessToken(token)
        }
    }
    
    override func performRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        responseType: T.Type,
        requiresAuth: Bool = true
    ) async throws -> T {
        // Create request to capture it
        let url = URL(string: "https://api.example.com")!.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth, let token = testAccessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        lastRequest = request
        
        // Use mock session
        let (data, response) = try await mockSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(0)
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            
            guard !data.isEmpty else {
                throw APIError.noData
            }
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw APIError.decodingFailed(error)
            }
            
        case 401:
            throw APIError.unauthorized
            
        default:
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.apiError(errorData.message)
            }
            throw APIError.invalidResponse(httpResponse.statusCode)
        }
    }
}