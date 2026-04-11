import Foundation

enum LoginFlowState: String, Codable, Equatable {
    case idle
    case preparing
    case openingBrowser
    case waitingAuthorization
    case exchangingToken
    case success
    case error
    case cancelled
}