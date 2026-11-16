import Foundation

/// Errors thrown when loading an incompatible or malformed save file.
public enum SaveGameError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
    case invalidMapDimensions
}

/// Versioned serializable snapshot of a player's city state.
public struct SaveGame: Codable, Equatable, Sendable {
    public static let currentVersion: Int = 1

    public var version: Int
    public var name: String
    public var seed: UInt64
    public var rngState: UInt64
    public var map: CityMap
    public var money: Int
    public var taxRate: Int
    public var date: GameDate
    public var stats: CityStats
    public var history: [MonthRecord]
    public var triggeredMilestones: [Int]
    public var negativeBankruptcyMonths: Int
    public var savedAt: Date

    public init(
        version: Int = SaveGame.currentVersion,
        name: String,
        seed: UInt64,
        rngState: UInt64,
        map: CityMap,
        money: Int,
        taxRate: Int,
        date: GameDate,
        stats: CityStats,
        history: [MonthRecord],
        triggeredMilestones: [Int] = [],
        negativeBankruptcyMonths: Int = 0,
        savedAt: Date = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded())
    ) {
        self.version = version
        self.name = name
        self.seed = seed
        self.rngState = rngState
        self.map = map
        self.money = money
        self.taxRate = taxRate
        self.date = date
        self.stats = stats
        self.history = history
        self.triggeredMilestones = triggeredMilestones
        self.negativeBankruptcyMonths = negativeBankruptcyMonths
        self.savedAt = savedAt
    }
}
