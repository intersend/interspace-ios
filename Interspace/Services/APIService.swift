import Foundation

class APIService {
    static let shared = APIService()

    private init() {}

    func authenticateWithApple(identityToken: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        // Here you would make a network request to your backend
        // For now, we will simulate a successful response
        let authResponse = AuthResponse(accessToken: "sample_access_token", refreshToken: "sample_refresh_token", expiresIn: 3600)
        completion(.success(authResponse))
    }
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}