import Foundation

struct QuotaCacheService {
    private struct QuotaCachePayload: Codable {
        var snapshotsByAccount: [String: QuotaSnapshot]
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var cacheFileURL: URL {
        FileSystemPaths.appSupportRoot.appendingPathComponent("quota_snapshot.json")
    }

    func save(snapshot: QuotaSnapshot, for accountId: String) throws {
        var payload = try loadPayload()
        payload.snapshotsByAccount[accountId] = snapshot
        try savePayload(payload)
    }

    func deleteSnapshot(for accountId: String) throws {
        var payload = try loadPayload()
        payload.snapshotsByAccount.removeValue(forKey: accountId)
        try savePayload(payload)
    }

    func loadSnapshot(for accountId: String) throws -> QuotaSnapshot? {
        try loadPayload().snapshotsByAccount[accountId]
    }

    func loadAllSnapshots() throws -> [String: QuotaSnapshot] {
        try loadPayload().snapshotsByAccount
    }

    private func loadPayload() throws -> QuotaCachePayload {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            return QuotaCachePayload(snapshotsByAccount: [:])
        }

        let data = try Data(contentsOf: cacheFileURL)
        return try decoder.decode(QuotaCachePayload.self, from: data)
    }

    private func savePayload(_ payload: QuotaCachePayload) throws {
        try FileSystemPaths.ensureRuntimeDirectoriesExist()

        let data = try encoder.encode(payload)
        try data.write(to: cacheFileURL)
    }
}
