import XCTest
@testable import Interspace

final class SimpleMPCTest: XCTestCase {
    
    override class func setUp() {
        super.setUp()
        // Setup test environment before any tests run
        MPCConfiguration.setupForTesting()
    }
    
    override class func tearDown() {
        super.tearDown()
        // Clean up after all tests
        MPCConfiguration.tearDownAfterTesting()
    }
    
    func testMPCConfigurationExists() {
        let config = MPCConfiguration.shared
        XCTAssertNotNil(config)
    }
    
    func testBasicMPCTypes() {
        // Test that basic types compile and work
        let algorithm = MPCAlgorithm.ecdsa
        XCTAssertEqual(algorithm.rawValue, "ecdsa")
        
        let sessionType = MPCSessionType.keyGeneration
        XCTAssertNotNil(sessionType)
        
        let error = MPCError.keyShareNotFound
        XCTAssertNotNil(error.errorDescription)
    }
}