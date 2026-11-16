import XCTest
@testable import CityCore

final class PlacementTests: XCTestCase {
    private func makeTestCity(money: Int = 5_000) -> City {
        var map = CityMap(width: 8, height: 8)
        map[GridPoint(x: 1, y: 1)].kind = .water
        map[GridPoint(x: 2, y: 2)].kind = .forest
        return City(name: "Test", map: map, money: money)
    }

    func testBuildCostsAndMoneyDeduction() {
        let city = makeTestCity(money: 5_000)
        let roadPt = GridPoint(x: 0, y: 0)
        XCTAssertEqual(city.apply(.road, at: roadPt), .placed(cost: 10))
        XCTAssertEqual(city.map[roadPt].kind, .road)
        XCTAssertEqual(city.money, 4_990)

        let resPt = GridPoint(x: 0, y: 1)
        XCTAssertEqual(city.apply(.residential, at: resPt), .placed(cost: 20))
        XCTAssertEqual(city.map[resPt].kind, .residential)
        XCTAssertEqual(city.money, 4_970)

        let plantPt = GridPoint(x: 3, y: 3)
        XCTAssertEqual(city.apply(.powerPlant, at: plantPt), .placed(cost: 3_000))
        XCTAssertEqual(city.map[plantPt].kind, .powerPlant)
        XCTAssertEqual(city.money, 1_970)
    }

    func testBuildOnWaterIsBlocked() {
        let city = makeTestCity()
        let waterPt = GridPoint(x: 1, y: 1)
        let res = city.apply(.road, at: waterPt)
        if case .blocked = res {
            // Expected
        } else {
            XCTFail("Expected blocked on water, got \(res)")
        }
        XCTAssertEqual(city.map[waterPt].kind, .water)
        XCTAssertEqual(city.money, 5_000)
    }

    func testBuildOnForestAddsClearingSurcharge() {
        let city = makeTestCity(money: 50)
        let forestPt = GridPoint(x: 2, y: 2)
        // Residential (20) + Forest clearing (10) = 30
        XCTAssertEqual(city.apply(.residential, at: forestPt), .placed(cost: 30))
        XCTAssertEqual(city.map[forestPt].kind, .residential)
        XCTAssertEqual(city.money, 20)
    }

    func testSameKindIsUnchangedAndNoCost() {
        let city = makeTestCity(money: 1_000)
        let p = GridPoint(x: 4, y: 4)
        XCTAssertEqual(city.apply(.park, at: p), .placed(cost: 100))
        XCTAssertEqual(city.apply(.park, at: p), .unchanged)
        XCTAssertEqual(city.money, 900)
    }

    func testOverwriteDifferentBuiltTileIsBlocked() {
        let city = makeTestCity(money: 1_000)
        let p = GridPoint(x: 4, y: 4)
        XCTAssertEqual(city.apply(.road, at: p), .placed(cost: 10))
        let res = city.apply(.commercial, at: p)
        if case .blocked = res {
            // Expected
        } else {
            XCTFail("Expected blocked when overwriting built tile, got \(res)")
        }
        XCTAssertEqual(city.map[p].kind, .road)
        XCTAssertEqual(city.money, 990)
    }

    func testNotEnoughMoneyRejectsPlacement() {
        let city = makeTestCity(money: 25)
        let forestPt = GridPoint(x: 2, y: 2)
        // Zone (20) + forest clear (10) = 30 > 25
        XCTAssertEqual(city.apply(.commercial, at: forestPt), .notEnoughMoney)
        XCTAssertEqual(city.map[forestPt].kind, .forest)
        XCTAssertEqual(city.money, 25)

        // PowerPlant costs 3000 > 25
        XCTAssertEqual(city.apply(.powerPlant, at: GridPoint(x: 0, y: 0)), .notEnoughMoney)
        XCTAssertEqual(city.money, 25)
    }

    func testBulldozeRules() {
        let city = makeTestCity(money: 1_000)
        let grassPt = GridPoint(x: 0, y: 0)
        let waterPt = GridPoint(x: 1, y: 1)
        let forestPt = GridPoint(x: 2, y: 2)
        let roadPt = GridPoint(x: 3, y: 3)

        XCTAssertEqual(city.apply(.bulldoze, at: grassPt), .unchanged)
        XCTAssertEqual(city.money, 1_000)

        if case .blocked = city.apply(.bulldoze, at: waterPt) {
            // Expected
        } else {
            XCTFail("Bulldozing water must be blocked")
        }

        XCTAssertEqual(city.apply(.bulldoze, at: forestPt), .placed(cost: 10))
        XCTAssertEqual(city.map[forestPt].kind, .grass)
        XCTAssertEqual(city.money, 990)

        XCTAssertEqual(city.apply(.road, at: roadPt), .placed(cost: 10))
        XCTAssertEqual(city.apply(.bulldoze, at: roadPt), .placed(cost: 5))
        XCTAssertEqual(city.map[roadPt].kind, .grass)
        XCTAssertEqual(city.money, 975)
    }

    func testInspectDoesNothingAndOutOfBoundsBlocked() {
        let city = makeTestCity()
        XCTAssertEqual(city.apply(.inspect, at: GridPoint(x: 0, y: 0)), .unchanged)
        if case .blocked = city.apply(.road, at: GridPoint(x: -1, y: 0)) {
            // Expected
        } else {
            XCTFail("Out of bounds must be blocked")
        }
    }
}
