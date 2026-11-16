import Foundation

/// Discrete 2D coordinate on the city tile grid.
public struct GridPoint: Hashable, Codable, Equatable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// Chebyshev (chessboard) distance between two grid points.
    public func chebyshevDistance(to other: GridPoint) -> Int {
        max(abs(x - other.x), abs(y - other.y))
    }

    /// Manhattan (4-way grid) distance between two grid points.
    public func manhattanDistance(to other: GridPoint) -> Int {
        abs(x - other.x) + abs(y - other.y)
    }
}
