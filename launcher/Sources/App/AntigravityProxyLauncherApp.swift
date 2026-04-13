import SwiftUI
import AppKit
import Darwin

@main
struct AntigravityProxyLauncherApp: App {
    @StateObject private var appState = LauncherAppState()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var quotaViewModel = QuotaViewModel()

    init() {
        do {
            try FileSystemPaths.ensureRuntimeDirectoriesExist()
        } catch {
            LauncherLogger.warn("Failed to ensure runtime directories: \(error.localizedDescription)")
        }

        switch LauncherCLICommandParser.parse(from: CommandLine.arguments) {
        case .doctor:
            Darwin.exit(LauncherDoctor().run())
        case .exportDiagnostics:
            Darwin.exit(LauncherDoctor().exportDiagnosticsFromCLI())
        case .verifyPatched:
            Darwin.exit(LauncherDoctor().verifyPatchedAppFromCLI())
        case .patchAndLaunch:
            Darwin.exit(LauncherDoctor().patchAndLaunchFromCLI())
        case .help:
            print(LauncherCLICommandParser.helpText)
            Darwin.exit(0)
        case .unknown(let arg):
            print("未知参数: \(arg)")
            print(LauncherCLICommandParser.helpText)
            Darwin.exit(2)
        case .none:
            let bundleIdentifier = Bundle.main.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if bundleIdentifier.isEmpty {
#if DEBUG
                print("当前进程缺少主 Bundle Identifier，已切换为开发模式继续启动 GUI。")
                LauncherLogger.warn("Missing bundle identifier in DEBUG run. Continue GUI bootstrap for local development.")
#else
                print("当前进程缺少主 Bundle Identifier，已跳过 GUI 启动。")
                print("请使用 .app 方式启动 GUI，或改用 CLI 诊断命令。")
                print(LauncherCLICommandParser.helpText)
                Darwin.exit(2)
#endif
            } else {
                LauncherLogger.info("GUI bootstrap with bundle identifier: \(bundleIdentifier)")
            }

            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            break
        }

        LauncherLogger.info("Launcher started in GUI mode. If no terminal output appears, check the app window in Dock/桌面。")
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appState)
                .environmentObject(authViewModel)
                .environmentObject(quotaViewModel)
                .frame(minWidth: 820, minHeight: 560)
        }
    }
}
