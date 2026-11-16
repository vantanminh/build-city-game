import XCTest
@testable import CityCore

final class IsoMathTests: XCTestCase {
    func testGridToSceneAndBackRoundTrip() {
        for y in 0..<48 {
            for x in 0..<48 {
                let pt = GridPoint(x: x, y: y)
                let scene = IsoMath.gridToScene(x: x, y: y)
                let decoded = IsoMath.sceneToGrid(x: scene.x, y: scene.y)
                XCTAssertEqual(decoded, pt)
            }
        }
    }

    func testPointsInsideTileDiamondMapToSameTile() {
        let target = GridPoint(x: 12, y: 19)
        let center = IsoMath.gridToScene(x: target.x, y: target.y)
        let offsets: [(Double, Double)] = [
            (0, 0),
            (10, 0),
            (-10, 0),
            (0, 8),
            (0, -8),
            (12, 5),
            (-12, -5)
        ]
        for (dx, dy) in offsets {
            let decoded = IsoMath.sceneToGrid(x: center.x + dx, y: center.y + dy)
            XCTAssertEqual(decoded, target)
        }
    }

    func testGridLineEndpointsAndContinuity() {
        let start = GridPoint(x: 2, y: 3)
        let end = GridPoint(x: 6, y: 5)
        let line = IsoMath.gridLine(from: start, to: end)
        XCTAssertEqual(line.first, start)
        XCTAssertEqual(line.last, end)
        for idx in 1..<line.count {
            XCTAssertEqual(line[idx - 1].manhattanDistance(to: line[idx]), 1)
        }
    }
}
