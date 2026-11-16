import XCTest
@testable import CityCore

final class SimulationTests: XCTestCase {
    func testZoneWithoutRoadAccessNeverGrows() {
        let map = CityMap(width: 10, height: 10)
        let city = City(name: "NoRoad", map: map, money: 50_000)
        // Power plant adjacent to residential zone, NO road anywhere!
        _ = city.apply(.powerPlant, at: GridPoint(x: 2, y: 2))
        _ = city.apply(.residential, at: GridPoint(x: 3, y: 2))

        var rng = SeededRandomNumberGenerator(seed: 123)
        for _ in 0..<120 {
            _ = city.step(rng: &rng)
        }

        XCTAssertTrue(city.map[GridPoint(x: 3, y: 2)].powered)
        XCTAssertFalse(city.map[GridPoint(x: 3, y: 2)].hasRoadAccess)
        XCTAssertEqual(city.map[GridPoint(x: 3, y: 2)].level, 0)
    }

    func testUnpoweredZoneNeverGrows() {
        let map = CityMap(width: 10, height: 10)
        let city = City(name: "NoPower", map: map, money: 50_000)
        _ = city.apply(.road, at: GridPoint(x: 2, y: 2))
        _ = city.apply(.residential, at: GridPoint(x: 3, y: 2))

        var rng = SeededRandomNumberGenerator(seed: 123)
        for _ in 0..<120 {
            _ = city.step(rng: &rng)
        }

        XCTAssertFalse(city.map[GridPoint(x: 3, y: 2)].powered)
        XCTAssertTrue(city.map[GridPoint(x: 3, y: 2)].hasRoadAccess)
        XCTAssertEqual(city.map[GridPoint(x: 3, y: 2)].level, 0)
    }

    func testDemandFormulasAndTaxPenalty() {
        var map = CityMap(width: 8, height: 8)
        // 2 residential tiles level 2 -> pop = 100
        map[GridPoint(x: 0, y: 0)] = Tile(kind: .residential, level: 2)
        map[GridPoint(x: 1, y: 0)] = Tile(kind: .residential, level: 2)
        // 1 commercial level 2 -> comJobs = 30
        map[GridPoint(x: 2, y: 0)] = Tile(kind: .commercial, level: 2)
        // 1 industrial level 1 -> indJobs = 20
        map[GridPoint(x: 3, y: 0)] = Tile(kind: .industrial, level: 1)

        let city = City(name: "DemandTest", map: map)
        city.taxRate = 9
        city.refreshInfrastructure()

        XCTAssertEqual(city.stats.population, 100)
        XCTAssertEqual(city.stats.commercialJobs, 30)
        XCTAssertEqual(city.stats.industrialJobs, 20)
        XCTAssertEqual(city.stats.jobs, 50)

        // resDemand = (50 * 1.1 + 60 - 100) / 120 = 15 / 120 = 0.125
        // comDemand = (100 * 0.35 - 30) / 60 = 5 / 60 = 0.083333...
        // indDemand = (100 * 0.45 - 20) / 60 = 25 / 60 = 0.416666...
        XCTAssertEqual(city.stats.resDemand, 15.0 / 120.0, accuracy: 1e-6)
        XCTAssertEqual(city.stats.comDemand, 5.0 / 60.0, accuracy: 1e-6)
        XCTAssertEqual(city.stats.indDemand, 25.0 / 60.0, accuracy: 1e-6)

        // Raising tax by +5 (to 14%) reduces each demand by 5 * 0.03 = 0.15
        city.taxRate = 14
        Simulation.recomputeStats(city: city)
        XCTAssertEqual(city.stats.resDemand, (15.0 / 120.0) - 0.15, accuracy: 1e-6)
        XCTAssertEqual(city.stats.comDemand, (5.0 / 60.0) - 0.15, accuracy: 1e-6)
        XCTAssertEqual(city.stats.indDemand, (25.0 / 60.0) - 0.15, accuracy: 1e-6)
    }

    func testDesirabilityBonusesAndResidentialOnlyPenalties() {
        var map = CityMap(width: 12, height: 12)
        map[GridPoint(x: 5, y: 5)].kind = .residential
        map[GridPoint(x: 5, y: 6)].kind = .commercial
        // 4 parks within radius 4 -> capped at +24
        map[GridPoint(x: 4, y: 5)].kind = .park
        map[GridPoint(x: 6, y: 5)].kind = .park
        map[GridPoint(x: 4, y: 6)].kind = .park
        map[GridPoint(x: 6, y: 6)].kind = .park
        // 2 industrial tiles within radius 4 -> -12 on R, 0 on C
        map[GridPoint(x: 3, y: 5)].kind = .industrial
        map[GridPoint(x: 7, y: 5)].kind = .industrial
        // 1 school within radius 8 -> +10
        map[GridPoint(x: 1, y: 1)].kind = .school

        let city = City(name: "Desire", map: map)
        city.refreshInfrastructure()

        // R at (5,5): 50 + 24 (parks) + 10 (school) - 12 (ind) = 72
        XCTAssertEqual(city.desirability(at: GridPoint(x: 5, y: 5)), 72)
        // C at (5,6): 50 + 24 (parks) + 10 (school) = 84 (no industrial penalty)
        XCTAssertEqual(city.desirability(at: GridPoint(x: 5, y: 6)), 84)
    }

    func testDeterministic365TickSimulationProducesIdenticalResult() {
        func runOneYear() -> City {
            let city = City(name: "SimCity", seed: 777, size: 24)
            let c = 12
            // Build starter cross road, power plant, and R/C/I zones in cleared center
            for offset in -3...3 {
                _ = city.apply(.road, at: GridPoint(x: c + offset, y: c))
            }
            _ = city.apply(.powerPlant, at: GridPoint(x: c - 2, y: c - 1))
            _ = city.apply(.residential, at: GridPoint(x: c - 1, y: c - 1))
            _ = city.apply(.residential, at: GridPoint(x: c, y: c - 1))
            _ = city.apply(.residential, at: GridPoint(x: c + 1, y: c - 1))
            _ = city.apply(.commercial, at: GridPoint(x: c - 1, y: c + 1))
            _ = city.apply(.industrial, at: GridPoint(x: c, y: c + 1))
            _ = city.apply(.park, at: GridPoint(x: c + 1, y: c + 1))

            var rng = SeededRandomNumberGenerator(seed: 999)
            for _ in 0..<365 {
                _ = city.step(rng: &rng)
            }
            return city
        }

        let cityA = runOneYear()
        let cityB = runOneYear()

        XCTAssertEqual(cityA.map, cityB.map)
        XCTAssertEqual(cityA.stats, cityB.stats)
        XCTAssertEqual(cityA.date, cityB.date)
        XCTAssertGreaterThan(cityA.stats.population, 0)
        XCTAssertGreaterThan(cityA.stats.jobs, 0)
    }

    func testDeclineWhenPowerDisconnected() {
        var map = CityMap(width: 8, height: 8)
        map[GridPoint(x: 0, y: 0)] = Tile(kind: .road)
        map[GridPoint(x: 1, y: 0)] = Tile(kind: .residential, level: 2)

        let city = City(name: "Decline", map: map)
        var rng = SeededRandomNumberGenerator(seed: 42)
        for _ in 0..<80 {
            _ = city.step(rng: &rng)
        }

        XCTAssertEqual(city.map[GridPoint(x: 1, y: 0)].level, 0)
    }
}
