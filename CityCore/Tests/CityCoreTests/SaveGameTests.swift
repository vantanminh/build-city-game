import XCTest
@testable import CityCore

final class SaveGameTests: XCTestCase {
    func testSaveGameJSONRoundTripPreservesStateAndContinuedSimulation() throws {
        let city = City(name: "Sài Gòn Mới", seed: 2026, size: 20)
        let c = 10
        for x in (c - 3)...(c + 3) {
            _ = city.apply(.road, at: GridPoint(x: x, y: c))
        }
        _ = city.apply(.powerPlant, at: GridPoint(x: c - 2, y: c - 1))
        _ = city.apply(.residential, at: GridPoint(x: c - 1, y: c - 1))
        _ = city.apply(.residential, at: GridPoint(x: c, y: c - 1))
        _ = city.apply(.commercial, at: GridPoint(x: c - 1, y: c + 1))
        _ = city.apply(.industrial, at: GridPoint(x: c, y: c + 1))
        city.taxRate = 11

        var rng = SeededRandomNumberGenerator(seed: city.seed)
        for _ in 0..<45 {
            _ = city.step(rng: &rng)
        }

        let snapshot = city.snapshot(rngState: rng.state)
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SaveGame.self, from: data)
        XCTAssertEqual(decoded, snapshot)

        let restored = try City(from: decoded)
        XCTAssertEqual(restored.name, city.name)
        XCTAssertEqual(restored.seed, city.seed)
        XCTAssertEqual(restored.money, city.money)
        XCTAssertEqual(restored.taxRate, city.taxRate)
        XCTAssertEqual(restored.date, city.date)
        XCTAssertEqual(restored.stats, city.stats)
        XCTAssertEqual(restored.history, city.history)
        XCTAssertEqual(restored.map, city.map)

        // Continuing simulation from restored RNG state must stay bit-for-bit identical.
        var restoredRng = SeededRandomNumberGenerator(state: restored.savedRngState)
        for _ in 0..<60 {
            _ = city.step(rng: &rng)
            _ = restored.step(rng: &restoredRng)
        }

        XCTAssertEqual(restored.map, city.map)
        XCTAssertEqual(restored.money, city.money)
        XCTAssertEqual(restored.stats, city.stats)
        XCTAssertEqual(restored.date, city.date)
    }

    func testUnsupportedVersionThrowsError() {
        let city = City(name: "Future", seed: 1, size: 16)
        var snapshot = city.snapshot()
        snapshot.version = 99

        XCTAssertThrowsError(try City(from: snapshot)) { error in
            XCTAssertEqual(error as? SaveGameError, .unsupportedVersion(99))
        }
    }
}
