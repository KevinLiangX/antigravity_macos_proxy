import Foundation

enum OAuthConstants {
    static let callbackHost = "127.0.0.1"
    static let callbackPath = "/callback"
    static let authTimeoutSeconds: TimeInterval = 120

    static let authEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    static let userInfoEndpoint = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!

    static let scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
        "https://www.googleapis.com/auth/cclog",
        "https://www.googleapis.com/auth/experimentsandconfigs"
    ].joined(separator: " ")

    // Fallback credentials aligned with AntigravityQuotaWatcherDesktop.
    // Environment variables still take precedence for private deployments.
    private static let defaultClientID = "YOUR_GOOGLE_CLIENT_ID_HERE"
    private static let defaultClientSecret = "YOUR_GOOGLE_CLIENT_SECRET_HERE"

    static var clientID: String {
        ProcessInfo.processInfo.environment["AG_GOOGLE_CLIENT_ID"] ?? defaultClientID
    }

    static var clientSecret: String {
        ProcessInfo.processInfo.environment["AG_GOOGLE_CLIENT_SECRET"] ?? defaultClientSecret
    }
}
