import CityCore
import Foundation

/// Outcome of attempting to load the saved city JSON file from disk.
enum SaveLoadResult {
    case missing
    case loaded(City, SaveGame)
    case corrupted
}

/// Persists `SaveGame` snapshots atomically as `Documents/city.json`.
final class SaveStore {
    private let directoryURL: URL
    private let fileName = "city.json"
    private let corruptFileName = "city.corrupt.json"

    init(
        directoryURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    ) {
        self.directoryURL = directoryURL
    }

    var saveFileURL: URL {
        directoryURL.appendingPathComponent(fileName)
    }

    var corruptFileURL: URL {
        directoryURL.appendingPathComponent(corruptFileName)
    }

    func save(_ snapshot: SaveGame) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: saveFileURL, options: [.atomic])
    }

    func load() -> SaveLoadResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: saveFileURL.path) else {
            return .missing
        }

        do {
            let data = try Data(contentsOf: saveFileURL)
            let snapshot = try JSONDecoder().decode(SaveGame.self, from: data)
            let city = try City(from: snapshot)
            return .loaded(city, snapshot)
        } catch {
            quarantineCorruptFile()
            return .corrupted
        }
    }

    func deleteSave() {
        try? FileManager.default.removeItem(at: saveFileURL)
    }

    private func quarantineCorruptFile() {
        let fm = FileManager.default
        if fm.fileExists(atPath: corruptFileURL.path) {
            try? fm.removeItem(at: corruptFileURL)
        }
        try? fm.moveItem(at: saveFileURL, to: corruptFileURL)
    }
}
