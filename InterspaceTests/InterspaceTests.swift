import XCTest
@testable import Interspace

final class InterspaceTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertTrue(true)
    }
    
    func testAppInitialization() throws {
        // Test that the app can be initialized
        let app = Interspace_iosApp()
        XCTAssertNotNil(app)
    }
}