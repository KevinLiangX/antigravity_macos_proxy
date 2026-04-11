import Foundation

struct DiagnosticsService {
    func exportSnapshot(status: AppStatus, appInfo: AppInfo?, quotaDiagnostics: [String: String]? = nil) throws -> URL {
        try FileManager.default.createDirectory(
            at: FileSystemPaths.diagnosticsRoot,
            withIntermediateDirectories: true
        )

        let fileURL = FileSystemPaths.diagnosticsRoot
            .appendingPathComponent("diagnostic-\(Int(Date().timeIntervalSince1970)).json")

        let snapshot = DiagnosticSnapshot(
            createdAt: Date(),
            appStatus: status.title,
            targetAppInfo: appInfo,
            lastPatchResult: nil,
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            quotaDiagnostics: quotaDiagnostics
        )

        let data = try JSONEncoder.pretty.encode(snapshot)
        try data.write(to: fileURL)
        return fileURL
    }

    func exportBundle(
        status: AppStatus,
        appInfo: AppInfo?,
        workflowItems: [LaunchWorkflowItem],
        logLines: [String],
        quotaDiagnostics: [String: String]? = nil
    ) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(
            at: FileSystemPaths.diagnosticsRoot,
            withIntermediateDirectories: true
        )

        let stamp = Int(Date().timeIntervalSince1970)
        let folder = FileSystemPaths.diagnosticsRoot
            .appendingPathComponent("diagnostic-\(stamp)", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        let summary = DiagnosticBundleSummaryData(
            createdAt: Date(),
            appStatusTitle: status.title,
            appStatusDescription: status.description,
            appInfo: appInfo,
            workflow: workflowItems.map { item in
                .init(step: item.title, state: String(describing: item.state), detail: item.detail)
            },
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            quotaDiagnostics: quotaDiagnostics
        )

        let summaryURL = folder.appendingPathComponent("summary.json")
        let summaryData = try JSONEncoder.pretty.encode(summary)
        try summaryData.write(to: summaryURL)

        let logsURL = folder.appendingPathComponent("runtime.log")
        let logsContent = logLines.joined(separator: "\n")
        try logsContent.write(to: logsURL, atomically: true, encoding: .utf8)

        return folder
    }

    func loadHistory(limit: Int = 30) -> [DiagnosticsHistoryEntry] {
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(
            at: FileSystemPaths.diagnosticsRoot,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let candidates = folders
            .filter { $0.hasDirectoryPath && $0.lastPathComponent.hasPrefix("diagnostic-") }

        let entries = candidates.compactMap { folder -> DiagnosticsHistoryEntry? in
            let summaryURL = folder.appendingPathComponent("summary.json")
            guard let data = try? Data(contentsOf: summaryURL) else { return nil }
            guard let summary = try? JSONDecoder().decode(DiagnosticBundleSummaryData.self, from: data) else { return nil }

            let hasFailure = summary.workflow.contains {
                $0.state.localizedCaseInsensitiveContains("failed")
            } || summary.appStatusTitle.contains("错误")

            return DiagnosticsHistoryEntry(
                id: folder.path,
                folderPath: folder.path,
                createdAt: summary.createdAt,
                statusTitle: summary.appStatusTitle,
                statusDescription: summary.appStatusDescription,
                hasFailure: hasFailure
            )
        }

        return entries
            .sorted(by: { $0.createdAt > $1.createdAt })
            .prefix(limit)
            .map { $0 }
    }

    func aggregateFailures(from history: [DiagnosticsHistoryEntry], top: Int = 5) -> [FailureAggregateEntry] {
        var counter: [String: Int] = [:]
        for item in history where item.hasFailure {
            counter[item.statusTitle, default: 0] += 1
        }

        return counter
            .map { FailureAggregateEntry(id: $0.key, reason: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(top)
            .map { $0 }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
