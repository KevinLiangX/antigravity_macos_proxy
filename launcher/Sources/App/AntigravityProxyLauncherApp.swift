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
