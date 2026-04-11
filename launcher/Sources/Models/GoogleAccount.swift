import Foundation

struct GoogleAccount: Codable, Equatable, Identifiable {
    let id: String
    let email: String
    var name: String?
    var avatarURL: String?
    var isActive: Bool
}