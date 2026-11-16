import XCTest
@testable import CityCore

final class TerrainAndMapTests: XCTestCase {
    func testMapBoundsNeighborsAndChebyshevPoints() {
        let map = CityMap(width: 10, height: 10)
        XCTAssertTrue(map.contains(GridPoint(x: 0, y: 0)))
        XCTAssertTrue(map.contains(GridPoint(x: 9, y: 9)))
        XCTAssertFalse(map.contains(GridPoint(x: -1, y: 0)))
        XCTAssertFalse(map.contains(GridPoint(x: 10, y: 5)))

        let cornerNeighbors = map.neighbors4(GridPoint(x: 0, y: 0))
        XCTAssertEqual(cornerNeighbors, [GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 1)])

        let innerPoints = map.points(within: 1, of: GridPoint(x: 5, y: 5))
        XCTAssertEqual(innerPoints.count, 9)

        let edgePoints = map.points(within: 2, of: GridPoint(x: 0, y: 0))
        XCTAssertEqual(edgePoints.count, 9)
    }

    func testRoadMaskConnections() {
        var map = CityMap(width: 5, height: 5)
        let center = GridPoint(x: 2, y: 2)
        XCTAssertEqual(map.roadMask(at: center), 0)

        map[center].kind = .road
        XCTAssertEqual(map.roadMask(at: center), 0)

        map[GridPoint(x: 2, y: 1)].kind = .road // N = 1
        map[GridPoint(x: 3, y: 2)].kind = .road // E = 2
        XCTAssertEqual(map.roadMask(at: center), 3)

        map[GridPoint(x: 2, y: 3)].kind = .road // S = 4
        map[GridPoint(x: 1, y: 2)].kind = .road // W = 8
        XCTAssertEqual(map.roadMask(at: center), 15)

        // Non-road neighbor does not set mask bits.
        map[GridPoint(x: 2, y: 1)].kind = .residential
        XCTAssertEqual(map.roadMask(at: center), 14)
    }

    func testSeededRandomDeterminism() {
        var rng1 = SeededRandomNumberGenerator(seed: 123_456)
        var rng2 = SeededRandomNumberGenerator(seed: 123_456)
        var rng3 = SeededRandomNumberGenerator(seed: 654_321)

        let seq1 = (0..<10).map { _ in rng1.next() }
        let seq2 = (0..<10).map { _ in rng2.next() }
        let seq3 = (0..<10).map { _ in rng3.next() }

        XCTAssertEqual(seq1, seq2)
        XCTAssertNotEqual(seq1, seq3)
    }

    func testTerrainGenerationDeterminismAndCenterClearance() {
        let mapA = TerrainGenerator.generate(size: 48, seed: 42)
        let mapB = TerrainGenerator.generate(size: 48, seed: 42)
        let mapC = TerrainGenerator.generate(size: 48, seed: 99)

        XCTAssertEqual(mapA, mapB)
        XCTAssertNotEqual(mapA, mapC)

        let center = GridPoint(x: 24, y: 24)
        for p in mapA.points(within: Balance.centerClearRadius, of: center) {
            XCTAssertEqual(mapA[p].kind, .grass, "Center area should stay clear grass at \(p)")
        }

        let waterCount = mapA.tiles.filter { $0.kind == .water }.count
        let forestCount = mapA.tiles.filter { $0.kind == .forest }.count
        XCTAssertGreaterThan(waterCount, 0)
        let forestRatio = Double(forestCount) / Double(mapA.tiles.count)
        XCTAssertGreaterThanOrEqual(forestRatio, 0.10)
        XCTAssertLessThanOrEqual(forestRatio, 0.20)
    }
}
