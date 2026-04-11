import Foundation

enum QuotaStatus: Equatable {
    case idle
    case fetching
    case retrying(Int)
    case ready
    case reauthRequired
    case error(String)
}