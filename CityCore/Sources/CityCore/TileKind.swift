import Foundation

/// Represents the terrain or built structure type of a map tile.
public enum TileKind: UInt8, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case grass
    case water
    case forest
    case road
    case residential
    case commercial
    case industrial
    case park
    case powerPlant
    case school
    case hospital

    /// Whether the tile is one of the three R/C/I developable zones.
    public var isZone: Bool {
        self == .residential || self == .commercial || self == .industrial
    }

    /// Whether the tile conducts electricity across adjacent neighbors.
    public var conductsPower: Bool {
        self != .grass && self != .water && self != .forest
    }

    /// Whether the tile consumes a unit of power plant capacity.
    public var consumesPower: Bool {
        isZone || self == .park || self == .school || self == .hospital
    }

    /// Whether the tile holds a player-built structure or zone (cannot be overwritten directly).
    public var isBuilt: Bool {
        self != .grass && self != .water && self != .forest
    }
}
