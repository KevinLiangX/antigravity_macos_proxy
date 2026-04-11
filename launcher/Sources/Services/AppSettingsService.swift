import Foundation

struct AppSettingsService {
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    func load() throws -> AppSettings {
        let url = FileSystemPaths.settingsFile
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .default
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(AppSettings.self, from: data)
    }

    func save(_ settings: AppSettings) throws {
        try FileSystemPaths.ensureRuntimeDirectoriesExist()

        let data = try encoder.encode(settings)
        try data.write(to: FileSystemPaths.settingsFile)
    }
}
