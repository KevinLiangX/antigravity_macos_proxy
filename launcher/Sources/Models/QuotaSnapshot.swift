import Foundation

struct QuotaSnapshot: Codable, Equatable {
    let timestamp: Date
    let userEmail: String
    let tier: String
    let models: [ModelQuotaInfo]
}