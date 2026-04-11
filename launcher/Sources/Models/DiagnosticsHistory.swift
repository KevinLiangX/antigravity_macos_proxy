import Foundation

struct DiagnosticsHistoryEntry: Identifiable, Equatable {
    let id: String
    let folderPath: String
    let createdAt: Date
    let statusTitle: String
    let statusDescription: String
    let hasFailure: Bool
}

struct FailureAggregateEntry: Identifiable, Equatable {
    let id: String
    let reason: String
    let count: Int
}

struct DiagnosticBundleSummaryData: Codable {
    struct WorkflowEntry: Codable {
        let step: String
        let state: String
        let detail: String?
    }

    let createdAt: Date
    let appStatusTitle: String
    let appStatusDescription: String
    let appInfo: AppInfo?
    let workflow: [WorkflowEntry]
    let systemVersion: String
    let quotaDiagnostics: [String: String]?
}
