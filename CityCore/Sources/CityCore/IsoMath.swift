import Foundation

/// Pure-Foundation isometric projection helpers shared between simulation and rendering.
public enum IsoMath {
    public static let tileWidth: Double = 64.0
    public static let tileHeight: Double = 32.0
    public static let halfWidth: Double = tileWidth * 0.5
    public static let halfHeight: Double = tileHeight * 0.5

    /// Converts a discrete grid point `(x, y)` to isometric scene coordinates `(sx, sy)`.
    public static func gridToScene(x: Int, y: Int) -> (x: Double, y: Double) {
        let dx = Double(x)
        let dy = Double(y)
        let sx = (dx - dy) * halfWidth
        let sy = -(dx + dy) * halfHeight
        return (sx, sy)
    }

    /// Converts isometric scene coordinates `(sx, sy)` back to the nearest `GridPoint`.
    public static func sceneToGrid(x sx: Double, y sy: Double) -> GridPoint {
        let a = sx / halfWidth
        let b = -sy / halfHeight
        let gx = Int(((a + b) * 0.5).rounded())
        let gy = Int(((b - a) * 0.5).rounded())
        return GridPoint(x: gx, y: gy)
    }

    /// Returns a 4-connected grid line from `start` to `end` so drag-painted roads stay unbroken.
    public static func gridLine(from start: GridPoint, to end: GridPoint) -> [GridPoint] {
        var points: [GridPoint] = []
        var x0 = start.x
        var y0 = start.y
        let x1 = end.x
        let y1 = end.y

        let dx = abs(x1 - x0)
        let dy = abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx - dy

        points.append(GridPoint(x: x0, y: y0))
        while x0 != x1 || y0 != y1 {
            let e2 = 2 * err
            let stepX = e2 > -dy
            let stepY = e2 < dx
            if stepX {
                err -= dy
                x0 += sx
            }
            if stepY {
                if stepX {
                    points.append(GridPoint(x: x0, y: y0))
                }
                err += dx
                y0 += sy
            }
            points.append(GridPoint(x: x0, y: y0))
        }
        return points
    }
}
