import Foundation

struct OAuthToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let tokenType: String
    let scope: String

    func isExpiring(within seconds: TimeInterval = 300) -> Bool {
        Date().addingTimeInterval(seconds) >= expiresAt
    }
}