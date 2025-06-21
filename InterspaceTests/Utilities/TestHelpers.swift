import Foundation
import XCTest
@testable import Interspace

// MARK: - Test Data Factories

struct TestDataFactory {
    
    // MARK: - User Factory
    
    static func createTestUser(
        id: String = "test-user-123",
        email: String? = "test@example.com",
        walletAddress: String? = "0x1234567890abcdef",
        isGuest: Bool = false,
        authStrategies: [String] = ["email"],
        profilesCount: Int = 1
    ) -> User {
        return User(
            id: id,
            email: email,
            walletAddress: walletAddress,
            isGuest: isGuest,
            authStrategies: authStrategies,
            profilesCount: profilesCount,
            linkedAccountsCount: 0,
            activeDevicesCount: 1,
            socialAccounts: [],
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    // MARK: - Authentication Factory
    
    static func createAuthResponse(
        accessToken: String = "test-access-token",
        refreshToken: String = "test-refresh-token",
        expiresIn: Int = 3600
    ) -> AuthenticationResponse {
        return AuthenticationResponse(
            success: true,
            data: AuthenticationData(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresIn: expiresIn,
                walletProfileInfo: nil
            ),
            message: "Authentication successful"
        )
    }
    
    // MARK: - Profile Factory
    
    static func createTestProfile(
        id: String = "profile-123",
        name: String = "Test Profile",
        isActive: Bool = true,
        icon: String = "🎮",
        color: String = "#FF0000"
    ) -> SmartProfile {
        return SmartProfile(
            id: id,
            userId: "test-user-123",
            name: name,
            icon: icon,
            color: color,
            isActive: isActive,
            linkedAccountsCount: 0,
            appsCount: 0,
            linkedAccounts: [],
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    // MARK: - Wallet Connection Factory
    
    static func createWalletConnectionConfig(
        strategy: AuthStrategy = .wallet,
        walletType: String? = "metamask",
        email: String? = nil,
        walletAddress: String? = "0x1234567890abcdef",
        signature: String? = "0xsignature123"
    ) -> WalletConnectionConfig {
        return WalletConnectionConfig(
            strategy: strategy,
            walletType: walletType,
            email: email,
            verificationCode: nil,
            walletAddress: walletAddress,
            signature: signature,
            socialProvider: nil,
            socialProfile: nil
        )
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {
    
    /// Wait for async expectation with timeout
    func waitForAsync(
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line,
        asyncBlock: @escaping () async throws -> Void
    ) {
        let expectation = self.expectation(description: "Async operation")
        
        Task {
            do {
                try await asyncBlock()
                expectation.fulfill()
            } catch {
                XCTFail("Async operation failed: \(error)", file: file, line: line)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
    }
    
    /// Assert async throwing expression
    func XCTAssertAsyncThrowsError<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail(message(), file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
    
    /// Assert async no throw
    func XCTAssertAsyncNoThrow<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
        } catch {
            XCTFail("Unexpected error: \(error) - \(message())", file: file, line: line)
        }
    }
}

// MARK: - Mock URL Session

class MockURLSession: URLSession {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    
    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        
        let data = mockData ?? Data()
        let response = mockResponse ?? HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        return (data, response)
    }
}

// MARK: - Test Observers

class TestObserver<T> {
    private var cancellables: Set<AnyCancellable> = []
    private(set) var values: [T] = []
    private(set) var valueCount = 0
    
    func observe(_ publisher: Published<T>.Publisher) {
        publisher
            .sink { [weak self] value in
                self?.values.append(value)
                self?.valueCount += 1
            }
            .store(in: &cancellables)
    }
    
    func reset() {
        values.removeAll()
        valueCount = 0
    }
}