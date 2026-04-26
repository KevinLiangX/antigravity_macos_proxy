import Foundation

enum TargetApp: String, Codable, CaseIterable, Identifiable {
    case antigravity
    case gemini
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .antigravity: return "Antigravity"
        case .gemini: return "Gemini"
        }
    }
    
    var bundleIdentifier: String {
        switch self {
        case .antigravity: return "com.google.antigravity"
        case .gemini: return "com.google.GeminiMacOS"
        }
    }
    
    var defaultPath: String {
        switch self {
        case .antigravity: return "/Applications/Antigravity.app"
        case .gemini: return "/Applications/Gemini.app"
        }
    }
    
    var patchedName: String {
        switch self {
        case .antigravity: return "Antigravity_Unlocked.app"
        case .gemini: return "Gemini_Unlocked.app"
        }
    }
    
    var launchArguments: [String] {
        switch self {
        case .antigravity:
            return ["--use-mock-keychain", "--password-store=basic"]
        case .gemini:
            return []
        }
    }
    
    var environmentVariables: [String: String] {
        switch self {
        case .antigravity:
            return [
                "ELECTRON_NO_UPDATER": "1",
                "SUDisableAutomaticChecks": "YES"
            ]
        case .gemini:
            return [:]
        }
    }
}
