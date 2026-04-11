import Foundation

struct DiagnosticSnapshot: Codable {
    let createdAt: Date
    let appStatus: String
    let targetAppInfo: AppInfo?
    let lastPatchResult: String?
    let systemVersion: String
    let quotaDiagnostics: [String: String]?
}
