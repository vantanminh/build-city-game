import XCTest
@testable import CityCore

final class PowerGridTests: XCTestCase {
    func testPowerConductsAcrossRoadsAndZonesAndStopsAtGrassGap() {
        var map = CityMap(width: 10, height: 10)
        map[GridPoint(x: 0, y: 0)].kind = .powerPlant
        map[GridPoint(x: 1, y: 0)].kind = .road
        map[GridPoint(x: 2, y: 0)].kind = .residential
        map[GridPoint(x: 3, y: 0)].kind = .commercial
        // Gap at (4, 0) = grass
        map[GridPoint(x: 5, y: 0)].kind = .residential

        PowerGrid.recompute(&map)

        XCTAssertTrue(map[GridPoint(x: 0, y: 0)].powered)
        XCTAssertTrue(map[GridPoint(x: 1, y: 0)].powered)
        XCTAssertTrue(map[GridPoint(x: 2, y: 0)].powered)
        XCTAssertTrue(map[GridPoint(x: 3, y: 0)].powered)
        XCTAssertFalse(map[GridPoint(x: 4, y: 0)].powered)
        XCTAssertFalse(map[GridPoint(x: 5, y: 0)].powered)
    }

    func testPowerPlantCapacityCutsOffExactlyAt80Consumers() {
        var map = CityMap(width: 12, height: 12)
        map[GridPoint(x: 0, y: 0)].kind = .powerPlant

        // Place 10 roads (non-consuming) + 85 consuming residential tiles in one connected component.
        for x in 1..<11 {
            map[GridPoint(x: x, y: 0)].kind = .road
        }

        var consumerPoints: [GridPoint] = []
        for y in 1...9 {
            for x in 0..<10 {
                if consumerPoints.count < 85 {
                    let p = GridPoint(x: x, y: y)
                    map[p].kind = .residential
                    consumerPoints.append(p)
                }
            }
        }
        // Connect row y=1 to plant at (0,0) and roads at y=0
        PowerGrid.recompute(&map)

        let poweredConsumers = consumerPoints.filter { map[$0].powered }.count
        let unpoweredConsumers = consumerPoints.filter { !map[$0].powered }.count
        XCTAssertEqual(poweredConsumers, Balance.powerPlantCapacity)
        XCTAssertEqual(unpoweredConsumers, 5)

        // Adding a second plant expands capacity to 160 -> all 85 powered.
        map[GridPoint(x: 11, y: 0)].kind = .powerPlant
        PowerGrid.recompute(&map)
        XCTAssertEqual(consumerPoints.filter { map[$0].powered }.count, 85)
    }

    func testNonConsumersDoNotConsumeCapacity() {
        var map = CityMap(width: 20, height: 10)
        map[GridPoint(x: 0, y: 0)].kind = .powerPlant
        for x in 1..<20 {
            map[GridPoint(x: x, y: 0)].kind = .road
        }

        var consumers: [GridPoint] = []
        for y in 1...4 {
            for x in 0..<20 {
                let p = GridPoint(x: x, y: y)
                map[p].kind = (x % 2 == 0) ? .residential : .park
                consumers.append(p)
            }
        }
        XCTAssertEqual(consumers.count, 80)

        PowerGrid.recompute(&map)
        XCTAssertTrue(consumers.allSatisfy { map[$0].powered })
    }
}
