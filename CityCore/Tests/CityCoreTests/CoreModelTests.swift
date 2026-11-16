import XCTest
@testable import CityCore

final class CoreModelTests: XCTestCase {
    func testTileKindFlags() {
        XCTAssertTrue(TileKind.residential.isZone)
        XCTAssertTrue(TileKind.commercial.isZone)
        XCTAssertTrue(TileKind.industrial.isZone)
        XCTAssertFalse(TileKind.road.isZone)
        XCTAssertFalse(TileKind.park.isZone)

        XCTAssertFalse(TileKind.grass.conductsPower)
        XCTAssertFalse(TileKind.water.conductsPower)
        XCTAssertFalse(TileKind.forest.conductsPower)
        XCTAssertTrue(TileKind.road.conductsPower)
        XCTAssertTrue(TileKind.powerPlant.conductsPower)
        XCTAssertTrue(TileKind.residential.conductsPower)

        XCTAssertFalse(TileKind.road.consumesPower)
        XCTAssertFalse(TileKind.powerPlant.consumesPower)
        XCTAssertTrue(TileKind.residential.consumesPower)
        XCTAssertTrue(TileKind.park.consumesPower)
        XCTAssertTrue(TileKind.school.consumesPower)
        XCTAssertTrue(TileKind.hospital.consumesPower)
    }

    func testToolCostsAndResultingKinds() {
        XCTAssertEqual(Tool.inspect.cost, 0)
        XCTAssertNil(Tool.inspect.resultingKind)
        XCTAssertEqual(Tool.road.cost, 10)
        XCTAssertEqual(Tool.road.resultingKind, .road)
        XCTAssertEqual(Tool.residential.cost, 20)
        XCTAssertEqual(Tool.commercial.cost, 20)
        XCTAssertEqual(Tool.industrial.cost, 20)
        XCTAssertEqual(Tool.park.cost, 100)
        XCTAssertEqual(Tool.powerPlant.cost, 3000)
        XCTAssertEqual(Tool.school.cost, 1500)
        XCTAssertEqual(Tool.hospital.cost, 2000)
        XCTAssertEqual(Tool.bulldoze.cost, 5)
        XCTAssertEqual(Tool.bulldoze.resultingKind, .grass)
    }

    func testGridPointDistances() {
        let a = GridPoint(x: 3, y: 4)
        let b = GridPoint(x: 6, y: 2)
        XCTAssertEqual(a.chebyshevDistance(to: b), 3)
        XCTAssertEqual(a.manhattanDistance(to: b), 5)
    }
}
