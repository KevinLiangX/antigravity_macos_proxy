import Foundation

struct ReleaseUpdateInfo: Equatable {
    let currentVersion: String
    let latestVersion: String
    let notes: String?
    let downloadURL: String?
    let isUpdateAvailable: Bool
}

struct ReleaseFeedPayload: Decodable {
    let latestVersion: String
    let notes: String?
    let downloadURL: String?

    private enum CodingKeys: String, CodingKey {
        case latestVersion
        case version
        case notes
        case releaseNotes
        case downloadURL
        case downloadUrl
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        latestVersion = try container.decodeIfPresent(String.self, forKey: .latestVersion)
            ?? container.decode(String.self, forKey: .version)

        notes = try container.decodeIfPresent(String.self, forKey: .notes)
            ?? container.decodeIfPresent(String.self, forKey: .releaseNotes)

        downloadURL = try container.decodeIfPresent(String.self, forKey: .downloadURL)
            ?? container.decodeIfPresent(String.self, forKey: .downloadUrl)
            ?? container.decodeIfPresent(String.self, forKey: .url)
    }
}