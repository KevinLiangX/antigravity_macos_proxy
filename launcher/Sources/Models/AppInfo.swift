import Foundation

struct AppInfo: Codable, Equatable {
    let appPath: String
    let bundleIdentifier: String
    let version: String
    let executableRelativePath: String
    let architectures: [String]
}
