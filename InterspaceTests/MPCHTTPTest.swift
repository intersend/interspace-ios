import XCTest
@testable import Interspace

// Simple HTTP connectivity test
final class MPCHTTPTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        MPCConfiguration.setupForTesting()
    }
    
    override func tearDown() {
        super.tearDown()
        MPCConfiguration.tearDownAfterTesting()
    }
    
    func testBackendConnectivity() async throws {
        // Test that we can reach the backend
        let config = MPCConfiguration.shared
        let url = URL(string: "\(config.backendBaseURL)/health")!
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        XCTAssertNotNil(response as? HTTPURLResponse)
        let httpResponse = response as! HTTPURLResponse
        XCTAssertEqual(httpResponse.statusCode, 200)
        
        // Check response data
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["status"] as? String, "healthy")
    }
    
    func testMPCConfiguration() {
        let config = MPCConfiguration.shared
        
        // Test HTTP configuration
        XCTAssertTrue(config.useHTTP)
        XCTAssertEqual(config.backendBaseURL, "http://localhost:3000")
        XCTAssertEqual(config.httpTimeout, 30.0)
        XCTAssertEqual(config.pollingInterval, 1.0)
        XCTAssertEqual(config.maxPollingDuration, 120.0)
    }
    
    func testHTTPSessionManager() {
        let manager = MPCHTTPSessionManager.shared
        XCTAssertNotNil(manager)
        
        // Test it's a singleton
        let manager2 = MPCHTTPSessionManager.shared
        XCTAssertTrue(manager === manager2)
    }
}