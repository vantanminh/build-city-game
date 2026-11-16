import Foundation

/// Outcome of applying a player tool on a map tile.
public enum PlacementResult: Equatable, Sendable {
    case placed(cost: Int)
    case unchanged
    case notEnoughMoney
    case blocked(reason: String)
}

/// Core mutable city model holding map state, treasury, date, stats, and rules.
public final class City {
    public var name: String
    public let seed: UInt64
    public var map: CityMap
    public var money: Int
    public var taxRate: Int {
        didSet {
            taxRate = max(Balance.minTaxRate, min(Balance.maxTaxRate, taxRate))
        }
    }
    public var date: GameDate
    public internal(set) var stats: CityStats
    public internal(set) var history: [MonthRecord]
    public var savedRngState: UInt64

    internal var mapDirty: Bool = true
    internal var ticksSincePowerUpdate: Int = 0
    internal var desirabilityGrid: [Int] = []
    internal var triggeredMilestones: Set<Int> = []
    internal var negativeBankruptcyMonths: Int = 0

    public init(name: String, seed: UInt64, size: Int = Balance.defaultMapSize) {
        self.name = name
        self.seed = seed
        self.savedRngState = seed
        self.map = TerrainGenerator.generate(size: size, seed: seed)
        self.money = Balance.startingMoney
        self.taxRate = Balance.defaultTaxRate
        self.date = GameDate()
        self.stats = CityStats()
        self.history = []
        self.desirabilityGrid = Array(repeating: Balance.baseDesirability, count: map.width * map.height)
    }

    public init(
        name: String,
        map: CityMap,
        seed: UInt64 = 0,
        money: Int = Balance.startingMoney,
        taxRate: Int = Balance.defaultTaxRate,
        date: GameDate = GameDate(),
        stats: CityStats = CityStats(),
        history: [MonthRecord] = []
    ) {
        self.name = name
        self.seed = seed
        self.savedRngState = seed
        self.map = map
        self.money = money
        self.taxRate = max(Balance.minTaxRate, min(Balance.maxTaxRate, taxRate))
        self.date = date
        self.stats = stats
        self.history = history
        self.desirabilityGrid = Array(repeating: Balance.baseDesirability, count: map.width * map.height)
    }

    /// Restores a city from a versioned `SaveGame` snapshot.
    public init(from save: SaveGame) throws {
        guard save.version == SaveGame.currentVersion else {
            throw SaveGameError.unsupportedVersion(save.version)
        }
        guard save.map.width > 0,
              save.map.height > 0,
              save.map.tiles.count == save.map.width * save.map.height else {
            throw SaveGameError.invalidMapDimensions
        }

        self.name = save.name
        self.seed = save.seed
        self.savedRngState = save.rngState
        self.map = save.map
        self.money = save.money
        self.taxRate = max(Balance.minTaxRate, min(Balance.maxTaxRate, save.taxRate))
        self.date = save.date
        self.stats = save.stats
        self.history = save.history
        self.triggeredMilestones = Set(save.triggeredMilestones)
        self.negativeBankruptcyMonths = save.negativeBankruptcyMonths
        self.desirabilityGrid = Array(repeating: Balance.baseDesirability, count: save.map.width * save.map.height)
        self.mapDirty = true
        self.refreshInfrastructure()
        self.stats.happiness = save.stats.happiness
    }

    /// Captures a serializable `SaveGame` snapshot of the current city state.
    public func snapshot(rngState: UInt64? = nil) -> SaveGame {
        if let rngState {
            savedRngState = rngState
        }
        return SaveGame(
            version: SaveGame.currentVersion,
            name: name,
            seed: seed,
            rngState: savedRngState,
            map: map,
            money: money,
            taxRate: taxRate,
            date: date,
            stats: stats,
            history: history,
            triggeredMilestones: triggeredMilestones.sorted(),
            negativeBankruptcyMonths: negativeBankruptcyMonths
        )
    }

    /// Cached desirability score (`0...100`) at grid point `p`.
    public func desirability(at p: GridPoint) -> Int {
        guard map.contains(p) else { return Balance.baseDesirability }
        let idx = p.y * map.width + p.x
        guard idx >= 0 && idx < desirabilityGrid.count else { return Balance.baseDesirability }
        return desirabilityGrid[idx]
    }

    /// Recomputes road access, power grid, desirability, and stats if the map has changed.
    @discardableResult
    public func refreshInfrastructure() -> [GridPoint] {
        guard mapDirty else { return [] }
        return Simulation.recomputeInfrastructure(city: self)
    }

    /// Advances the city simulation by 1 day using a caller-provided RNG.
    public func step(rng: inout some RandomNumberGenerator) -> StepResult {
        Simulation.step(city: self, rng: &rng)
    }

    /// Applies `tool` at grid coordinate `p` following all placement and cost rules.
    public func apply(_ tool: Tool, at p: GridPoint) -> PlacementResult {
        guard map.contains(p) else {
            return .blocked(reason: "Ngoài phạm vi bản đồ")
        }

        if tool == .inspect {
            return .unchanged
        }

        let current = map[p]

        if tool == .bulldoze {
            return applyBulldoze(at: p, current: current)
        }

        guard let targetKind = tool.resultingKind else {
            return .unchanged
        }

        if current.kind == .water {
            return .blocked(reason: "Không thể xây trên mặt nước")
        }

        if current.kind == targetKind {
            return .unchanged
        }

        if current.kind.isBuilt {
            return .blocked(reason: "Đã có công trình, cần phá bỏ trước")
        }

        let clearCost = (current.kind == .forest) ? Balance.forestClearCost : 0
        let totalCost = tool.cost + clearCost

        guard money >= totalCost else {
            return .notEnoughMoney
        }

        money -= totalCost
        var updated = current
        updated.kind = targetKind
        updated.level = 0
        updated.powered = false
        updated.hasRoadAccess = false
        map[p] = updated
        mapDirty = true
        return .placed(cost: totalCost)
    }

    private func applyBulldoze(at p: GridPoint, current: Tile) -> PlacementResult {
        switch current.kind {
        case .water:
            return .blocked(reason: "Không thể phá mặt nước")
        case .grass:
            return .unchanged
        case .forest:
            let cost = Balance.forestClearCost
            guard money >= cost else { return .notEnoughMoney }
            money -= cost
            resetTileToGrass(at: p, variant: current.variant)
            return .placed(cost: cost)
        default:
            let cost = Balance.bulldozeCost
            guard money >= cost else { return .notEnoughMoney }
            money -= cost
            resetTileToGrass(at: p, variant: current.variant)
            return .placed(cost: cost)
        }
    }

    private func resetTileToGrass(at p: GridPoint, variant: UInt8) {
        map[p] = Tile(kind: .grass, level: 0, powered: false, hasRoadAccess: false, variant: variant)
        mapDirty = true
    }
}
