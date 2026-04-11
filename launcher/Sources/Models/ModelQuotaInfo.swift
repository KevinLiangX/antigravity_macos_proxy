import Foundation

struct ModelQuotaInfo: Codable, Equatable, Identifiable {
    let modelId: String
    let displayName: String
    let remainingFraction: Double
    let remainingPercentage: Double
    let isExhausted: Bool
    let resetTime: Date?

    var id: String {
        modelId
    }
}