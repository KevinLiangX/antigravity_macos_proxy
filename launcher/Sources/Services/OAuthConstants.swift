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

    private static let placeholderClientID = "YOUR_GOOGLE_CLIENT_ID_HERE"
    private static let placeholderClientSecret = "YOUR_GOOGLE_CLIENT_SECRET_HERE"

    static var clientID: String {
        let env = ProcessInfo.processInfo.environment["AG_GOOGLE_CLIENT_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty {
            return env
        }

        let saved = appSettingsCredential().id
        if !saved.isEmpty {
            return saved
        }

        return placeholderClientID
    }

    static var clientSecret: String {
        let env = ProcessInfo.processInfo.environment["AG_GOOGLE_CLIENT_SECRET"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty {
            return env
        }

        let saved = appSettingsCredential().secret
        if !saved.isEmpty {
            return saved
        }

        return placeholderClientSecret
    }

    static var hasValidClientCredential: Bool {
        isValid(clientID) && isValid(clientSecret)
    }

    private static func isValid(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return false
        }
        if value == placeholderClientID || value == placeholderClientSecret {
            return false
        }
        if value.hasPrefix("YOUR_GOOGLE_CLIENT_") {
            return false
        }
        return true
    }

    private static func appSettingsCredential() -> (id: String, secret: String) {
        guard let settings = try? AppSettingsService().load() else {
            return ("", "")
        }

        return (
            settings.googleOAuthClientID.trimmingCharacters(in: .whitespacesAndNewlines),
            settings.googleOAuthClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
