import Foundation

/// User preferences, persisted as JSON in
/// ~/Library/Application Support/Lockin/settings.json
struct Settings: Codable {
    var holdSeconds: Double
    var emergencyEscEnabled: Bool
    var blockSpotlight: Bool
    var debounceMs: Int

    static let defaults = Settings(
        holdSeconds: 3.0,
        emergencyEscEnabled: true,
        blockSpotlight: true,
        debounceMs: 300
    )

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lockin", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    static func load() -> Settings {
        guard let data = try? Data(contentsOf: fileURL),
              let s = try? JSONDecoder().decode(Settings.self, from: data)
        else { return .defaults }
        return s
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self) {
            try? data.write(to: Self.fileURL)
        }
    }
}
