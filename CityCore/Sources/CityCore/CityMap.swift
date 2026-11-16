import Foundation

/// 2D grid storing all tiles of a city in row-major order (`y * width + x`).
public struct CityMap: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public private(set) var tiles: [Tile]

    public init(width: Int, height: Int, defaultTile: Tile = Tile()) {
        precondition(width > 0 && height > 0, "CityMap dimensions must be positive")
        self.width = width
        self.height = height
        self.tiles = Array(repeating: defaultTile, count: width * height)
    }

    public init(size: Int = Balance.defaultMapSize, defaultTile: Tile = Tile()) {
        self.init(width: size, height: size, defaultTile: defaultTile)
    }

    public subscript(p: GridPoint) -> Tile {
        get {
            precondition(contains(p), "GridPoint \(p) out of bounds (\(width)x\(height))")
            return tiles[p.y * width + p.x]
        }
        set {
            precondition(contains(p), "GridPoint \(p) out of bounds (\(width)x\(height))")
            tiles[p.y * width + p.x] = newValue
        }
    }

    /// Safe lookup that returns `nil` when `p` is outside the map bounds.
    public func tile(at p: GridPoint) -> Tile? {
        guard contains(p) else { return nil }
        return tiles[p.y * width + p.x]
    }

    /// Returns `true` when `p` lies inside `[0..<width, 0..<height]`.
    public func contains(_ p: GridPoint) -> Bool {
        p.x >= 0 && p.x < width && p.y >= 0 && p.y < height
    }

    /// Returns the valid orthogonal neighbors of `p` in N, E, S, W order.
    public func neighbors4(_ p: GridPoint) -> [GridPoint] {
        let candidates = [
            GridPoint(x: p.x, y: p.y - 1),
            GridPoint(x: p.x + 1, y: p.y),
            GridPoint(x: p.x, y: p.y + 1),
            GridPoint(x: p.x - 1, y: p.y)
        ]
        return candidates.filter { contains($0) }
    }

    /// Returns all in-bounds points within Chebyshev distance `r` of `p` (inclusive).
    public func points(within r: Int, of p: GridPoint) -> [GridPoint] {
        guard r >= 0 else { return [] }
        let minX = max(0, p.x - r)
        let maxX = min(width - 1, p.x + r)
        let minY = max(0, p.y - r)
        let maxY = min(height - 1, p.y + r)
        guard minX <= maxX && minY <= maxY else { return [] }

        var result: [GridPoint] = []
        result.reserveCapacity((maxX - minX + 1) * (maxY - minY + 1))
        for y in minY...maxY {
            for x in minX...maxX {
                result.append(GridPoint(x: x, y: y))
            }
        }
        return result
    }

    /// Computes a 4-bit road connectivity mask at `p` (N=1, E=2, S=4, W=8).
    /// Returns `0` if `p` is out of bounds or not a road tile.
    public func roadMask(at p: GridPoint) -> UInt8 {
        guard contains(p), self[p].kind == .road else { return 0 }
        var mask: UInt8 = 0
        if tile(at: GridPoint(x: p.x, y: p.y - 1))?.kind == .road { mask |= 1 }
        if tile(at: GridPoint(x: p.x + 1, y: p.y))?.kind == .road { mask |= 2 }
        if tile(at: GridPoint(x: p.x, y: p.y + 1))?.kind == .road { mask |= 4 }
        if tile(at: GridPoint(x: p.x - 1, y: p.y))?.kind == .road { mask |= 8 }
        return mask
    }
}
