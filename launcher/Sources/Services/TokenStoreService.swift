import Foundation

enum TokenStoreError: Error {
    case encodeFailed
    case decodeFailed
    case fileSystemError(Error)
    case keychainError(Error)
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
        case .keychainError(let error):
            return "Keychain error: \(error.localizedDescription)"
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
        
        // Ensure directory exists (for migration and backward compatibility if needed)
        try? FileManager.default.createDirectory(
            at: tokensDirectory,
            withIntermediateDirectories: true
        )
        
        // Migrate any existing tokens from disk to Keychain
        migrateFromDiskToKeychain()
    }

    private func migrateFromDiskToKeychain() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: tokensDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for fileURL in files where fileURL.pathExtension == "json" {
            let accountId = fileURL.deletingPathExtension().lastPathComponent
            do {
                let data = try Data(contentsOf: fileURL)
                // Attempt to decode to ensure it's a valid token
                _ = try decoder.decode(OAuthToken.self, from: data)
                
                // Save to Keychain
                try KeychainService.save(key: keychainKey(for: accountId), data: data)
                
                // Delete the file after successful migration
                try fm.removeItem(at: fileURL)
                print("Migrated token for \(accountId) to Keychain.")
            } catch {
                print("Failed to migrate token for \(accountId): \(error)")
            }
        }
    }

    private func keychainKey(for accountId: String) -> String {
        return "oauth_token_\(accountId)"
    }

    func saveToken(_ token: OAuthToken, for accountId: String, allowUserInteraction: Bool = true) throws {
        let payload: Data
        do {
            payload = try encoder.encode(token)
        } catch {
            throw TokenStoreError.encodeFailed
        }

        do {
            try KeychainService.save(key: keychainKey(for: accountId), data: payload)
        } catch {
            throw TokenStoreError.keychainError(error)
        }
    }

    func loadToken(for accountId: String, allowUserInteraction: Bool = true) throws -> OAuthToken? {
        do {
            guard let data = try KeychainService.load(key: keychainKey(for: accountId)) else {
                return nil
            }
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
        do {
            try KeychainService.delete(key: keychainKey(for: accountId))
        } catch {
            throw TokenStoreError.keychainError(error)
        }
    }

    func clearAllTokens() throws {
        do {
            try KeychainService.deleteAll()
            
            // Also clean up the directory if anything was left
            let files = try FileManager.default.contentsOfDirectory(at: tokensDirectory, includingPropertiesForKeys: nil)
            for fileURL in files {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            throw TokenStoreError.keychainError(error)
        }
    }
}