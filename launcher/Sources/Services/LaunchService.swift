import Foundation
import AppKit

final class LaunchService {
    private var activeAppPID: pid_t?

    init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopManagedPatchedApp()
        }
    }

    func launchPatchedApp(settings: AppSettings? = nil) async throws {
        stopManagedPatchedApp()

        let dylibPath = FileSystemPaths.patchedApp
            .appendingPathComponent("Contents/Resources/libAntigravityTun.dylib")
            .path
        let configPath = FileSystemPaths.patchedApp
            .appendingPathComponent("Contents/Resources/proxy_config.json")
            .path

        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["--use-mock-keychain", "--password-store=basic"]
        var env = ProcessInfo.processInfo.environment
        env["ELECTRON_NO_UPDATER"] = "1"
        env["SUDisableAutomaticChecks"] = "YES"
        env["DYLD_INSERT_LIBRARIES"] = dylibPath
        env["ANTIGRAVITY_CONFIG"] = configPath
        
        if settings?.enableRuntimeLog == true {
            try FileManager.default.createDirectory(
                at: FileSystemPaths.runtimeLogsRoot,
                withIntermediateDirectories: true
            )
            env["ANTIGRAVITY_LOG_FILE"] = "1"
            env["ANTIGRAVITY_LOG_LEVEL"] = settings?.runtimeLogLevel ?? "Info"
            env["ANTIGRAVITY_LOG_PATH"] = FileSystemPaths.runtimeLogFile.path
        } else {
            env.removeValue(forKey: "ANTIGRAVITY_LOG_FILE")
            env.removeValue(forKey: "ANTIGRAVITY_LOG_LEVEL")
            env.removeValue(forKey: "ANTIGRAVITY_LOG_PATH")
        }
        
        config.environment = env
        config.createsNewApplicationInstance = true
        config.promptsUserIfNeeded = false

        let app = try await NSWorkspace.shared.openApplication(
            at: FileSystemPaths.patchedApp,
            configuration: config
        )
        self.activeAppPID = app.processIdentifier
    }

    func launchOriginalApp() async throws {
        let config = NSWorkspace.OpenConfiguration()
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "DYLD_INSERT_LIBRARIES")
        env.removeValue(forKey: "ANTIGRAVITY_CONFIG")
        config.environment = env
        config.createsNewApplicationInstance = true
        config.promptsUserIfNeeded = false

        let app = try await NSWorkspace.shared.openApplication(
            at: FileSystemPaths.targetApp,
            configuration: config
        )
        self.activeAppPID = app.processIdentifier
    }

    func stopManagedPatchedApp() {
        var running = runningPatchedApps()
        guard !running.isEmpty else {
            activeAppPID = nil
            return
        }

        if let bundleID = patchedBundleIdentifier() {
            requestGracefulQuit(bundleIdentifier: bundleID)
        }

        for app in running {
            _ = app.terminate()
        }

        let deadline = Date().addingTimeInterval(1.5)
        while Date() < deadline {
            running = runningPatchedApps()
            if running.isEmpty {
                activeAppPID = nil
                return
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }

        for app in running {
            _ = app.forceTerminate()
        }
        activeAppPID = nil
    }

    func isPatchedAppRunning() -> Bool {
        !runningPatchedApps().isEmpty
    }

    func runtimeEnvironmentDescription() -> [String: String] {
        let dylibPath = FileSystemPaths.patchedApp
            .appendingPathComponent("Contents/Resources/libAntigravityTun.dylib")
            .path
        let configPath = FileSystemPaths.patchedApp
            .appendingPathComponent("Contents/Resources/proxy_config.json")
            .path

        return [
            "DYLD_INSERT_LIBRARIES": dylibPath,
            "ANTIGRAVITY_CONFIG": configPath
        ]
    }

    private func runningPatchedApps() -> [NSRunningApplication] {
        let patchedPath = FileSystemPaths.patchedApp.standardizedFileURL.path

        if let bundleID = patchedBundleIdentifier() {
            return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter { app in
                guard let bundlePath = app.bundleURL?.standardizedFileURL.path else {
                    return activeAppPID == app.processIdentifier
                }
                return bundlePath == patchedPath
            }
        }

        if let pid = activeAppPID, let app = NSRunningApplication(processIdentifier: pid) {
            return [app]
        }
        return []
    }

    private func patchedBundleIdentifier() -> String? {
        let infoURL = FileSystemPaths.patchedApp.appendingPathComponent("Contents/Info.plist")
        let dict = NSDictionary(contentsOf: infoURL) as? [String: Any]
        return dict?["CFBundleIdentifier"] as? String
    }

    private func requestGracefulQuit(bundleIdentifier: String) {
        let script = "tell application id \"\(bundleIdentifier)\" to quit"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
        process.waitUntilExit()
    }
}
