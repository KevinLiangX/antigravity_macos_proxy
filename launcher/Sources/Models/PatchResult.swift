import Foundation

struct PatchResult: Equatable {
    let success: Bool
    let message: String
    let outputPath: String?
}
