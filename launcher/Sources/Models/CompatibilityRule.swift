import Foundation

struct CompatibilityRule: Codable, Equatable {
    let minVersion: String
    let maxVersion: String
    let bundleIdentifier: String
    let executableRelativePath: String
}

struct CompatibilityRegistry: Codable {
    let schemaVersion: Int
    let rules: [CompatibilityRule]
}
