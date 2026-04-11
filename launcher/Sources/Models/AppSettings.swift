import Foundation

struct AppSettings: Codable, Equatable {
    var autoExportDiagnosticsOnFailure: Bool
    var launchAfterPatch: Bool
    var quotaAutoRefreshEnabled: Bool
    var quotaPollingIntervalSeconds: Int
    var compatibilityRulesURL: String
    var compatibilityTrustedHosts: String
    var compatibilityExpectedSHA256: String
    var releaseFeedURL: String
    var releaseFeedTrustedHosts: String
    var releaseIgnoredVersion: String

    static let `default` = AppSettings(
        autoExportDiagnosticsOnFailure: true,
        launchAfterPatch: true,
        quotaAutoRefreshEnabled: false,
        quotaPollingIntervalSeconds: 60,
        compatibilityRulesURL: "",
        compatibilityTrustedHosts: "githubusercontent.com, raw.githubusercontent.com",
        compatibilityExpectedSHA256: "",
        releaseFeedURL: "",
        releaseFeedTrustedHosts: "githubusercontent.com, raw.githubusercontent.com",
        releaseIgnoredVersion: ""
    )

    enum CodingKeys: String, CodingKey {
        case autoExportDiagnosticsOnFailure
        case launchAfterPatch
        case quotaAutoRefreshEnabled
        case quotaPollingIntervalSeconds
        case compatibilityRulesURL
        case compatibilityTrustedHosts
        case compatibilityExpectedSHA256
        case releaseFeedURL
        case releaseFeedTrustedHosts
        case releaseIgnoredVersion
    }

    init(
        autoExportDiagnosticsOnFailure: Bool,
        launchAfterPatch: Bool,
        quotaAutoRefreshEnabled: Bool,
        quotaPollingIntervalSeconds: Int,
        compatibilityRulesURL: String,
        compatibilityTrustedHosts: String,
        compatibilityExpectedSHA256: String,
        releaseFeedURL: String,
        releaseFeedTrustedHosts: String,
        releaseIgnoredVersion: String
    ) {
        self.autoExportDiagnosticsOnFailure = autoExportDiagnosticsOnFailure
        self.launchAfterPatch = launchAfterPatch
        self.quotaAutoRefreshEnabled = quotaAutoRefreshEnabled
        self.quotaPollingIntervalSeconds = quotaPollingIntervalSeconds
        self.compatibilityRulesURL = compatibilityRulesURL
        self.compatibilityTrustedHosts = compatibilityTrustedHosts
        self.compatibilityExpectedSHA256 = compatibilityExpectedSHA256
        self.releaseFeedURL = releaseFeedURL
        self.releaseFeedTrustedHosts = releaseFeedTrustedHosts
        self.releaseIgnoredVersion = releaseIgnoredVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autoExportDiagnosticsOnFailure = try container.decodeIfPresent(Bool.self, forKey: .autoExportDiagnosticsOnFailure) ?? true
        launchAfterPatch = try container.decodeIfPresent(Bool.self, forKey: .launchAfterPatch) ?? true
        quotaAutoRefreshEnabled = try container.decodeIfPresent(Bool.self, forKey: .quotaAutoRefreshEnabled) ?? false
        quotaPollingIntervalSeconds = max(5, try container.decodeIfPresent(Int.self, forKey: .quotaPollingIntervalSeconds) ?? 60)
        compatibilityRulesURL = try container.decodeIfPresent(String.self, forKey: .compatibilityRulesURL) ?? ""
        compatibilityTrustedHosts = try container.decodeIfPresent(String.self, forKey: .compatibilityTrustedHosts)
            ?? "githubusercontent.com, raw.githubusercontent.com"
        compatibilityExpectedSHA256 = try container.decodeIfPresent(String.self, forKey: .compatibilityExpectedSHA256) ?? ""
        releaseFeedURL = try container.decodeIfPresent(String.self, forKey: .releaseFeedURL) ?? ""
        releaseFeedTrustedHosts = try container.decodeIfPresent(String.self, forKey: .releaseFeedTrustedHosts)
            ?? "githubusercontent.com, raw.githubusercontent.com"
        releaseIgnoredVersion = try container.decodeIfPresent(String.self, forKey: .releaseIgnoredVersion) ?? ""
    }
}
