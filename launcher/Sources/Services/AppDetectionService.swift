import Foundation

struct AppDetectionService {
    func detectInstalledTargetApp() -> AppInfo? {
        let appURL = FileSystemPaths.targetApp
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            return nil
        }

        let infoPlist = appURL.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: infoPlist) as? [String: Any] else {
            return nil
        }

        let bundleID = dict["CFBundleIdentifier"] as? String ?? ""
        let version = dict["CFBundleShortVersionString"] as? String
            ?? (dict["CFBundleVersion"] as? String ?? "unknown")
        let executable = dict["CFBundleExecutable"] as? String ?? "Electron"
        let executableRelativePath = "Contents/MacOS/\(executable)"
        let executablePath = appURL.appendingPathComponent(executableRelativePath).path
        let architectures = detectArchitectures(executablePath: executablePath)

        return AppInfo(
            appPath: appURL.path,
            bundleIdentifier: bundleID,
            version: version,
            executableRelativePath: executableRelativePath,
            architectures: architectures
        )
    }

    private func detectArchitectures(executablePath: String) -> [String] {
        do {
            let result = try CommandRunner.run("/usr/bin/lipo", ["-archs", executablePath])
            let values = result.stdout
                .split(whereSeparator: \ .isWhitespace)
                .map(String.init)
            return values
        } catch {
            return []
        }
    }
}
