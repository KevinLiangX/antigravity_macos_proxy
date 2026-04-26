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
    // WARNING: Fallback credentials are for development convenience only.
    // In production, these should be provided via environment variables or encrypted config.
    private static let fallbackClientID = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
    private static let fallbackClientSecret = "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"
    private static let bundledCredential = loadBundledCredential()

    static var bundledDefaultClientID: String {
        bundledCredential.id
    }

    static var bundledDefaultClientSecret: String {
        bundledCredential.secret
    }

    static var clientID: String {
        let env = ProcessInfo.processInfo.environment["AG_GOOGLE_CLIENT_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty {
            return env
        }

        let saved = appSettingsCredential().id
        if !saved.isEmpty {
            return saved
        }

        if !bundledCredential.id.isEmpty {
            return bundledCredential.id
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

        if !bundledCredential.secret.isEmpty {
            return bundledCredential.secret
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

    private struct BundledOAuthCredential: Decodable {
        let clientID: String
        let clientSecret: String

        enum CodingKeys: String, CodingKey {
            case clientID = "client_id"
            case clientSecret = "client_secret"
        }
    }

    private static func loadBundledCredential() -> (id: String, secret: String) {
        let fallback = (
            fallbackClientID.trimmingCharacters(in: .whitespacesAndNewlines),
            fallbackClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        guard let data = try? Data(contentsOf: FileSystemPaths.bundledGoogleOAuthClientConfig),
              let decoded = try? JSONDecoder().decode(BundledOAuthCredential.self, from: data) else {
            return fallback
        }

        let id = decoded.clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = decoded.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        if id.isEmpty || secret.isEmpty {
            return fallback
        }

        return (id, secret)
    }
}
