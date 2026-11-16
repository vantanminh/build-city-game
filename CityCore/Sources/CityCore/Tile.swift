import Foundation

/// State stored for a single tile on the city grid.
public struct Tile: Codable, Equatable, Hashable, Sendable {
    public var kind: TileKind
    public var level: UInt8
    public var powered: Bool
    public var hasRoadAccess: Bool
    public var variant: UInt8

    public init(
        kind: TileKind = .grass,
        level: UInt8 = 0,
        powered: Bool = false,
        hasRoadAccess: Bool = false,
        variant: UInt8 = 0
    ) {
        self.kind = kind
        self.level = level
        self.powered = powered
        self.hasRoadAccess = hasRoadAccess
        self.variant = variant
    }
}
