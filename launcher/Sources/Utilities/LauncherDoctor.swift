import Foundation

struct LauncherDoctor {
    private let detection = AppDetectionService()
    private let compatibility = CompatibilityService()
    private let diagnostics = DiagnosticsService()
    private let verifier = PatchVerificationService()
    private let patch = PatchService()
    private let migration = MigrationService()
    private let launch = LaunchService()

    func run() -> Int32 {
        print("=== Antigravity Proxy Launcher Doctor ===")
        print("时间: \(Date())")
        print("目标路径: \(FileSystemPaths.targetApp.path)")
        print("修复路径: \(FileSystemPaths.patchedApp.path)")

        guard let app = detection.detectInstalledTargetApp() else {
            let failure = LauncherFailure(code: .targetAppMissing, message: "未检测到原版 App")
            print("错误: \(failure.formatted)")
            print("建议: 确保 /Applications/Antigravity.app 存在")
            return failure.codeValue
        }

        print("状态: 检测到原版 App")
        print("Bundle ID: \(app.bundleIdentifier)")
        print("Version: \(app.version)")
        print("Executable: \(app.executableRelativePath)")
        print("Architectures: \(app.architectures.joined(separator: ", "))")

        do {
            let registry = try compatibility.loadRegistry()
            let supported = compatibility.isSupported(app, registry: registry)
            print("兼容性: \(supported ? "支持" : "不支持")")
            if !supported {
                let failure = LauncherFailure(code: .unsupportedVersion, message: "目标版本不在兼容列表")
                print("错误: \(failure.formatted)")
                print("建议: 更新 Sources/Compatibility/compatibility.json")
                return failure.codeValue
            }
        } catch {
            let failure = LauncherErrorMapper.map(error)
            print("兼容性检查失败: \(failure.formatted)")
            return failure.codeValue
        }

        let dylibExists = FileManager.default.fileExists(atPath: FileSystemPaths.bundledDylib.path)
            || FileManager.default.fileExists(atPath: FileSystemPaths.fallbackProxyRepoDylib.path)
        print("Dylib 资源: \(dylibExists ? "已找到" : "缺失")")

        if !dylibExists {
            let failure = LauncherFailure(code: .runtimeAssetMissing, message: "libAntigravityTun.dylib 缺失")
            print("错误: \(failure.formatted)")
            print("建议: 放置 libAntigravityTun.dylib 到 launcher/Resources 或兄弟仓库 antigravity_macos_proxy/")
            return failure.codeValue
        }

        print("Doctor 检查完成: 可继续执行 GUI 修复流程。")
        return LauncherErrorCode.success.rawValue
    }

    func exportDiagnosticsFromCLI() -> Int32 {
        let code = run()
        if code != 0 {
            print("导出已跳过: 先修复 doctor 检查失败项。")
            return code
        }

        do {
            let app = detection.detectInstalledTargetApp()
            let folder = try diagnostics.exportBundle(
                status: .targetAppInstalled,
                appInfo: app,
                workflowItems: [],
                logLines: ["CLI export generated at \(Date())"]
            )
            print("诊断包已导出: \(folder.path)")
            return LauncherErrorCode.success.rawValue
        } catch {
            let failure = LauncherFailure(code: .diagnosticsExportFailed, message: error.localizedDescription)
            print("诊断包导出失败: \(failure.formatted)")
            return failure.codeValue
        }
    }

    func verifyPatchedAppFromCLI() -> Int32 {
        do {
            try verifier.verifyPatchedResult()
            print("patched app 验证通过")
            return LauncherErrorCode.success.rawValue
        } catch {
            let failure = LauncherErrorMapper.map(error)
            print("patched app 验证失败: \(failure.formatted)")
            return failure.codeValue
        }
    }

    func patchAndLaunchFromCLI() -> Int32 {
        print("=== Antigravity Proxy Launcher CLI Patch Workflow ===")

        let doctorCode = run()
        if doctorCode != 0 {
            print("中止: doctor 检查未通过。")
            return doctorCode
        }

        do {
            print("[1/4] 迁移数据")
            try migration.migrateSandboxData()

            print("[2/4] 执行 patch")
            try patch.preparePatchedBundle(onProgress: { message in
                print("  - \(message)")
            })

            print("[3/4] 验证 patch")
            try verifier.verifyPatchedResult()

            print("[4/4] 启动修复版")
            try runAsyncBlocking {
                try await launch.launchPatchedApp()
            }

            print("CLI 全流程执行成功")
            return LauncherErrorCode.success.rawValue
        } catch {
            let failure = LauncherErrorMapper.map(error)
            print("CLI 全流程执行失败: \(failure.formatted)")
            return failure.codeValue
        }
    }

    private func runAsyncBlocking<T>(_ operation: @escaping () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var outcome: Result<T, Error>?

        Task {
            do {
                outcome = .success(try await operation())
            } catch {
                outcome = .failure(error)
            }
            semaphore.signal()
        }

        semaphore.wait()
        return try outcome!.get()
    }
}
