import Foundation

enum LauncherLogger {
    static func info(_ message: String) {
        print("[INFO] \(message)")
    }

    static func warn(_ message: String) {
        fputs("[WARN] \(message)\n", stderr)
    }

    static func error(_ message: String) {
        fputs("[ERROR] \(message)\n", stderr)
    }
}
