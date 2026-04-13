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
    // Shared fallback credentials aligned with AntigravityQuotaWatcherDesktop.
    private static let sharedDefaultClientID = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
    private static let sharedDefaultClientSecret = "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"

    static var clientID: String {
        let env = ProcessInfo.processInfo.environment["AG_GOOGLE_CLIENT_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty {
            return env
        }

        let saved = appSettingsCredential().id
        if !saved.isEmpty {
            return saved
        }

        let bundled = bundledCredential().id
        if !bundled.isEmpty {
            return bundled
        }

        return sharedDefaultClientID
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

        let bundled = bundledCredential().secret
        if !bundled.isEmpty {
            return bundled
        }

        return sharedDefaultClientSecret
    }

    static var hasValidClientCredential: Bool {
        isValid(clientID) && isValid(clientSecret)
    }

    static var teamSharedCredentialFileURL: URL {
        FileSystemPaths.launcherRoot.appendingPathComponent("Resources/google_oauth_client.json")
    }

    static var teamSharedCredentialFilePath: String {
        teamSharedCredentialFileURL.path
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

    private static func bundledCredential() -> (id: String, secret: String) {
        for candidate in bundledCredentialCandidates() {
            guard let data = try? Data(contentsOf: candidate),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let id = (json["client_id"] as? String ?? json["clientID"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let secret = (json["client_secret"] as? String ?? json["clientSecret"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !id.isEmpty || !secret.isEmpty {
                return (id, secret)
            }
        }

        return ("", "")
    }

    private static func bundledCredentialCandidates() -> [URL] {
        var candidates: [URL] = []

        if let url = Bundle.main.url(forResource: "google_oauth_client", withExtension: "json") {
            candidates.append(url)
        }

#if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "google_oauth_client", withExtension: "json") {
            candidates.append(url)
        }
#endif

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        candidates.append(cwd.appendingPathComponent("Resources/google_oauth_client.json"))
        candidates.append(cwd.appendingPathComponent("launcher/Resources/google_oauth_client.json"))

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // launcher

        candidates.append(repoRoot.appendingPathComponent("launcher/Resources/google_oauth_client.json"))
        candidates.append(repoRoot.appendingPathComponent("Resources/google_oauth_client.json"))

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.path).inserted }
    }
}
