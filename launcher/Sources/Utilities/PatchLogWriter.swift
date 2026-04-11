import Foundation

enum PatchLogWriter {
    private static let queue = DispatchQueue(label: "antigravity.patch.log.writer")

    static func beginSession() {
        append("\n===== Patch Session \(ISO8601DateFormatter().string(from: Date())) =====")
    }

    static func append(_ message: String) {
        queue.sync {
            do {
                let fileURL = FileSystemPaths.patchLogFile
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                let line = "[\(timestamp())] \(message)\n"
                let data = Data(line.utf8)

                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let handle = try FileHandle(forWritingTo: fileURL)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } else {
                    try data.write(to: fileURL)
                }
            } catch {
                // Do not fail patch flow for logging failures.
            }
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}
