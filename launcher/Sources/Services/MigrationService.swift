import Foundation

struct MigrationService {
    func migrateSandboxData() throws {
        guard FileSystemPaths.activeApp == .antigravity else {
            return
        }
        
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let destination = home.appendingPathComponent("Library/Application Support/Antigravity")
        let sources = findPossibleSandboxSources(baseHome: home)

        guard !sources.isEmpty else {
            return
        }

        try fm.createDirectory(at: destination, withIntermediateDirectories: true)

        for source in sources {
            _ = try CommandRunner.run(
                "/usr/bin/rsync",
                ["-av", "--update", source.path + "/", destination.path + "/"]
            )
        }

        resetTCCPermissions()
    }

    private func findPossibleSandboxSources(baseHome home: URL) -> [URL] {
        let fm = FileManager.default
        let containersRoot = home.appendingPathComponent("Library/Containers", isDirectory: true)
        guard let containerFolders = try? fm.contentsOfDirectory(
            at: containersRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var result: [URL] = []
        for container in containerFolders {
            let name = container.lastPathComponent.lowercased()
            if name == "antigravity" || name.hasSuffix(".antigravity") {
                let appSupport = container
                    .appendingPathComponent("Data/Library/Application Support/Antigravity", isDirectory: true)
                if fm.fileExists(atPath: appSupport.path) {
                    result.append(appSupport)
                }
            }
        }
        return result
    }

    private func resetTCCPermissions() {
        let identities = [
            "Antigravity",
            "com.google.antigravity",
            "com.apple.antigravity",
            "Antigravity_Unlocked",
            "Gemini",
            "com.google.GeminiMacOS",
            "Gemini_Unlocked"
        ]

        for identity in identities {
            _ = try? CommandRunner.run("/usr/bin/tccutil", ["reset", "All", identity])
        }
    }
}
