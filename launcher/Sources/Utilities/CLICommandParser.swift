import Foundation

enum LauncherCLICommand: Equatable {
    case doctor
    case exportDiagnostics
    case verifyPatched
    case patchAndLaunch
    case help
    case unknown(String)
    case none
}

enum LauncherCLICommandParser {
    static func parse(from args: [String]) -> LauncherCLICommand {
        let cliArgs = Array(args.dropFirst())

        for arg in cliArgs {
            if arg == "--" {
                continue
            }

            switch arg {
            case "--doctor": return .doctor
            case "--export-diagnostics": return .exportDiagnostics
            case "--verify-patched": return .verifyPatched
            case "--patch-and-launch": return .patchAndLaunch
            case "--help", "-h": return .help
            default:
                if arg.hasPrefix("--") || arg == "-h" {
                    return .unknown(arg)
                }
            }
        }

        return .none
    }

    static var helpText: String {
        """
Usage:
  AntigravityProxyLauncherCLI --doctor
  AntigravityProxyLauncherCLI --export-diagnostics
  AntigravityProxyLauncherCLI --verify-patched
  AntigravityProxyLauncherCLI --patch-and-launch
  AntigravityProxyLauncherCLI --help

Legacy SwiftPM mode:
  swift run AntigravityProxyLauncher
  swift run AntigravityProxyLauncher -- --doctor
  swift run AntigravityProxyLauncher -- --export-diagnostics
  swift run AntigravityProxyLauncher -- --verify-patched
  swift run AntigravityProxyLauncher -- --patch-and-launch
  swift run AntigravityProxyLauncher -- --help
"""
    }
}