import CityCore
import CoreGraphics

/// CoreGraphics bridge over `CityCore.IsoMath`.
enum SceneIsoMath {
    static let tileWidth: CGFloat = CGFloat(IsoMath.tileWidth)
    static let tileHeight: CGFloat = CGFloat(IsoMath.tileHeight)
    static let halfWidth: CGFloat = CGFloat(IsoMath.halfWidth)
    static let halfHeight: CGFloat = CGFloat(IsoMath.halfHeight)

    static func gridToScene(_ point: GridPoint) -> CGPoint {
        let coords = IsoMath.gridToScene(x: point.x, y: point.y)
        return CGPoint(x: coords.x, y: coords.y)
    }

    static func sceneToGrid(_ scenePoint: CGPoint) -> GridPoint {
        IsoMath.sceneToGrid(x: Double(scenePoint.x), y: Double(scenePoint.y))
    }

    static func zPosition(for point: GridPoint, extra: CGFloat = 0) -> CGFloat {
        CGFloat(point.x + point.y) + extra
    }
}
