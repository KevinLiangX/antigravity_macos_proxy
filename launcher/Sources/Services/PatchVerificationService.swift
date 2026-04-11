import Foundation

struct CodeSignVerifyFailureDetail {
    let command: String
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

enum PatchVerificationError: LocalizedError {
    case patchedAppMissing(String)
    case infoPlistMissing(String)
    case executableMissing(String)
    case dylibMissing(String)
    case configMissing(String)
    case invalidLSEnvironment
    case codeSignVerifyFailed(CodeSignVerifyFailureDetail)

    var errorDescription: String? {
        switch self {
        case .patchedAppMissing(let path):
            return "验证失败: patched app 不存在 -> \(path)"
        case .infoPlistMissing(let path):
            return "验证失败: Info.plist 不存在 -> \(path)"
        case .executableMissing(let path):
            return "验证失败: 主执行文件不存在 -> \(path)"
        case .dylibMissing(let path):
            return "验证失败: dylib 不存在 -> \(path)"
        case .configMissing(let path):
            return "验证失败: 配置文件不存在 -> \(path)"
        case .invalidLSEnvironment:
            return "验证失败: LSEnvironment 缺失或内容不正确"
        case .codeSignVerifyFailed(let detail):
            let stdout = detail.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let stderr = detail.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "验证失败: codesign --verify 未通过\ncommand: \(detail.command)\nexit: \(detail.exitCode)\nstdout: \(stdout)\nstderr: \(stderr)"
        }
    }
}

struct PatchVerificationService {
    func verifyPatchedResult() throws {
        let appURL = FileSystemPaths.patchedApp
        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")

        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw PatchVerificationError.patchedAppMissing(appURL.path)
        }

        guard FileManager.default.fileExists(atPath: infoURL.path) else {
            throw PatchVerificationError.infoPlistMissing(infoURL.path)
        }

        guard let info = NSDictionary(contentsOf: infoURL) as? [String: Any] else {
            throw PatchVerificationError.invalidLSEnvironment
        }

        let executableName = info["CFBundleExecutable"] as? String ?? "Electron"
        let executablePath = appURL
            .appendingPathComponent("Contents/MacOS/\(executableName)")
            .path

        let dylibPath = appURL
            .appendingPathComponent("Contents/Resources/libAntigravityTun.dylib")
            .path

        let configPath = appURL
            .appendingPathComponent("Contents/Resources/proxy_config.json")
            .path

        guard FileManager.default.fileExists(atPath: executablePath) else {
            throw PatchVerificationError.executableMissing(executablePath)
        }

        guard FileManager.default.fileExists(atPath: dylibPath) else {
            throw PatchVerificationError.dylibMissing(dylibPath)
        }

        guard FileManager.default.fileExists(atPath: configPath) else {
            throw PatchVerificationError.configMissing(configPath)
        }

        let expectedDylibPath = "@executable_path/../Resources/libAntigravityTun.dylib"
        let expectedConfigPath = "@executable_path/../Resources/proxy_config.json"

        guard let lsEnvironment = info["LSEnvironment"] as? [String: String],
              lsEnvironment["DYLD_INSERT_LIBRARIES"] == expectedDylibPath,
              lsEnvironment["ANTIGRAVITY_CONFIG"] == expectedConfigPath else {
            throw PatchVerificationError.invalidLSEnvironment
        }

        let helperFrameworks = appURL.appendingPathComponent("Contents/Frameworks", isDirectory: true)
        let helperApps = (try? FileManager.default.contentsOfDirectory(
            at: helperFrameworks,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ))?.filter { $0.pathExtension == "app" && $0.lastPathComponent.contains("Helper") } ?? []

        if !helperApps.isEmpty {
            let helperReady = helperApps.contains { helper in
                let helperResources = helper.appendingPathComponent("Contents/Resources", isDirectory: true)
                let helperDylib = helperResources.appendingPathComponent("libAntigravityTun.dylib").path
                let helperConfig = helperResources.appendingPathComponent("proxy_config.json").path
                return FileManager.default.fileExists(atPath: helperDylib)
                    && FileManager.default.fileExists(atPath: helperConfig)
            }

            if !helperReady {
                throw PatchVerificationError.invalidLSEnvironment
            }
        }

        let args = ["--verify", "--deep", "--strict", "--verbose=4", appURL.path]
        let commandText = "/usr/bin/codesign " + args.joined(separator: " ")

        do {
            _ = try CommandRunner.run("/usr/bin/codesign", args)
        } catch let commandError as CommandRunnerError {
            switch commandError {
            case .nonZeroExit(let result):
                throw PatchVerificationError.codeSignVerifyFailed(
                    .init(
                        command: commandText,
                        exitCode: result.status,
                        stdout: result.stdout,
                        stderr: result.stderr
                    )
                )
            case .executableNotFound:
                throw PatchVerificationError.codeSignVerifyFailed(
                    .init(
                        command: commandText,
                        exitCode: -1,
                        stdout: "",
                        stderr: commandError.localizedDescription
                    )
                )
            }
        } catch {
            throw PatchVerificationError.codeSignVerifyFailed(
                .init(
                    command: commandText,
                    exitCode: -1,
                    stdout: "",
                    stderr: error.localizedDescription
                )
            )
        }
    }
}
