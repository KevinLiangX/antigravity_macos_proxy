import Foundation

enum TokenStoreError: Error {
    case encodeFailed
    case decodeFailed
    case fileSystemError(Error)
    case tokenExpired
}

extension TokenStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .encodeFailed:
            return "Failed to encode OAuth token."
        case .decodeFailed:
            return "Failed to decode OAuth token."
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .tokenExpired:
            return "Token has expired."
        }
    }
}

struct TokenStoreService {
    private let tokensDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        self.tokensDirectory = FileSystemPaths.appSupportRoot.appendingPathComponent("oauth_tokens")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(
            at: tokensDirectory,
            withIntermediateDirectories: true
        )
    }

    func saveToken(_ token: OAuthToken, for accountId: String, allowUserInteraction: Bool = true) throws {
        let payload: Data
        do {
            payload = try encoder.encode(token)
        } catch {
            throw TokenStoreError.encodeFailed
        }

        let tokenFileURL = tokensDirectory.appendingPathComponent("\(accountId).json")
        
        do {
            try payload.write(to: tokenFileURL, options: .atomic)
        } catch {
            throw TokenStoreError.fileSystemError(error)
        }
    }

    func loadToken(for accountId: String, allowUserInteraction: Bool = true) throws -> OAuthToken? {
        let tokenFileURL = tokensDirectory.appendingPathComponent("\(accountId).json")
        
        guard FileManager.default.fileExists(atPath: tokenFileURL.path) else {
            return nil
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: tokenFileURL)
        } catch {
            throw TokenStoreError.fileSystemError(error)
        }
        
        do {
            return try decoder.decode(OAuthToken.self, from: data)
        } catch {
            throw TokenStoreError.decodeFailed
        }
    }

    func hasToken(for accountId: String, allowUserInteraction: Bool = true) -> Bool {
        do {
            return try loadToken(for: accountId, allowUserInteraction: allowUserInteraction) != nil
        } catch {
            return false
        }
    }

    func deleteToken(for accountId: String) throws {
        let tokenFileURL = tokensDirectory.appendingPathComponent("\(accountId).json")
        
        if FileManager.default.fileExists(atPath: tokenFileURL.path) {
            do {
                try FileManager.default.removeItem(at: tokenFileURL)
            } catch {
                throw TokenStoreError.fileSystemError(error)
            }
        }
    }

    func clearAllTokens() throws {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: tokensDirectory,
                includingPropertiesForKeys: nil
            )
            
            for fileURL in fileURLs {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            throw TokenStoreError.fileSystemError(error)
        }
    }
}