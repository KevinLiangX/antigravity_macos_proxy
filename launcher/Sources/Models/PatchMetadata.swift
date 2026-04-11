import Foundation

struct PatchMetadata: Codable, Equatable {
    let launcherVersion: String
    let targetVersion: String
    let patchedAt: Date
    let dylibChecksum: String
    let configChecksum: String
}
