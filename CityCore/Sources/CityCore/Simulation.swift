import Foundation

/// Outcome of advancing the city simulation by one day.
public struct StepResult: Equatable, Sendable {
    public var changed: [GridPoint]
    public var events: [CityEvent]

    public init(changed: [GridPoint] = [], events: [CityEvent] = []) {
        self.changed = changed
        self.events = events
    }
}

/// Significant events emitted by a simulation tick or month closing.
public enum CityEvent: Equatable, Sendable {
    case monthEnded(income: Int, expenses: Int)
    case milestone(String)
    case bankrupt
}

/// Pure simulation engine operating on `City` state.
public enum Simulation {
    /// Recomputes road access, power grid, desirability, and aggregate stats if the map changed.
    /// Returns coordinates whose visual power state changed.
    @discardableResult
    public static func recomputeInfrastructure(city: City) -> [GridPoint] {
        recomputeRoadAccess(map: &city.map)
        let powerChanged = PowerGrid.recompute(&city.map)
        city.ticksSincePowerUpdate = 0
        recomputeDesirability(city: city)
        recomputeStats(city: city)
        city.mapDirty = false
        return powerChanged
    }

    /// Advances `city` by 1 game day using `rng`.
    public static func step(city: City, rng: inout some RandomNumberGenerator) -> StepResult {
        var changedSet: Set<GridPoint> = []
        var changedOrder: [GridPoint] = []
        var events: [CityEvent] = []

        func recordChanged(_ point: GridPoint) {
            if changedSet.insert(point).inserted {
                changedOrder.append(point)
            }
        }

        if city.mapDirty {
            for p in recomputeInfrastructure(city: city) {
                recordChanged(p)
            }
        } else {
            city.ticksSincePowerUpdate += 1
            if city.ticksSincePowerUpdate >= Balance.powerRecomputeInterval {
                city.ticksSincePowerUpdate = 0
                for p in PowerGrid.recompute(&city.map) {
                    recordChanged(p)
                }
            }
        }

        // Refresh stats before evaluating growth/decline.
        recomputeStats(city: city)

        // Step 5.6: Zone growth & decline (~10% of zones, minimum 1).
        let growthChanged = stepZoneGrowth(city: city, rng: &rng)
        for p in growthChanged {
            recordChanged(p)
        }

        if !growthChanged.isEmpty {
            recomputeStats(city: city)
        }

        // Step 5.7: Happiness smoothing.
        updateHappiness(city: city)

        // Step 4 & 6: Advance date; month closing hook (full Economy added in M5).
        let monthEnded = city.date.advanceDay()
        if monthEnded {
            events.append(.monthEnded(income: 0, expenses: 0))
        }

        return StepResult(changed: changedOrder, events: events)
    }

    // MARK: - Road Access

    private static func recomputeRoadAccess(map: inout CityMap) {
        for y in 0..<map.height {
            for x in 0..<map.width {
                let p = GridPoint(x: x, y: y)
                var tile = map[p]
                if tile.kind.isBuilt {
                    let hasRoad = map.points(within: Balance.roadAccessRadius, of: p)
                        .contains { map[$0].kind == .road }
                    tile.hasRoadAccess = hasRoad
                } else {
                    tile.hasRoadAccess = false
                }
                map[p] = tile
            }
        }
    }

    // MARK: - Desirability

    private static func recomputeDesirability(city: City) {
        let map = city.map
        let count = map.width * map.height
        if city.desirabilityGrid.count != count {
            city.desirabilityGrid = Array(repeating: Balance.baseDesirability, count: count)
        }

        var parks: [GridPoint] = []
        var schools: [GridPoint] = []
        var hospitals: [GridPoint] = []
        var industrials: [GridPoint] = []
        var powerPlants: [GridPoint] = []

        for y in 0..<map.height {
            for x in 0..<map.width {
                let p = GridPoint(x: x, y: y)
                switch map[p].kind {
                case .park: parks.append(p)
                case .school: schools.append(p)
                case .hospital: hospitals.append(p)
                case .industrial: industrials.append(p)
                case .powerPlant: powerPlants.append(p)
                default: break
                }
            }
        }

        for y in 0..<map.height {
            for x in 0..<map.width {
                let p = GridPoint(x: x, y: y)
                let tile = map[p]
                var score = Balance.baseDesirability

                var parkBonus = 0
                for park in parks where p.chebyshevDistance(to: park) <= Balance.parkDesirabilityRadius {
                    parkBonus += Balance.parkDesirabilityBonus
                    if parkBonus >= Balance.parkDesirabilityMaxBonus {
                        parkBonus = Balance.parkDesirabilityMaxBonus
                        break
                    }
                }
                score += parkBonus

                if schools.contains(where: { p.chebyshevDistance(to: $0) <= Balance.schoolDesirabilityRadius }) {
                    score += Balance.schoolDesirabilityBonus
                }
                if hospitals.contains(where: { p.chebyshevDistance(to: $0) <= Balance.hospitalDesirabilityRadius }) {
                    score += Balance.hospitalDesirabilityBonus
                }

                var hasWater = false
                var hasForest = false
                for near in map.points(within: Balance.waterDesirabilityRadius, of: p) {
                    let nearKind = map[near].kind
                    if nearKind == .water { hasWater = true }
                    if nearKind == .forest { hasForest = true }
                    if hasWater && hasForest { break }
                }
                if hasWater { score += Balance.waterDesirabilityBonus }
                if hasForest { score += Balance.forestDesirabilityBonus }

                if tile.kind == .residential {
                    var indPenalty = 0
                    for ind in industrials where p.chebyshevDistance(to: ind) <= Balance.industrialDesirabilityRadius {
                        indPenalty += Balance.industrialDesirabilityPenalty
                        if indPenalty <= Balance.industrialDesirabilityMaxPenalty {
                            indPenalty = Balance.industrialDesirabilityMaxPenalty
                            break
                        }
                    }
                    score += indPenalty

                    if powerPlants.contains(where: { p.chebyshevDistance(to: $0) <= Balance.powerPlantDesirabilityRadius }) {
                        score += Balance.powerPlantDesirabilityPenalty
                    }
                }

                city.desirabilityGrid[y * map.width + x] = max(0, min(100, score))
            }
        }
    }

    // MARK: - Stats & Demand

    public static func recomputeStats(city: City) {
        var pop = 0
        var comJobs = 0
        var indJobs = 0
        var consumerCount = 0
        var unpoweredCount = 0
        var noRoadCount = 0

        for tile in city.map.tiles {
            switch tile.kind {
            case .residential:
                pop += Int(tile.level) * Balance.populationPerResidentialLevel
            case .commercial:
                comJobs += Int(tile.level) * Balance.jobsPerCommercialLevel
            case .industrial:
                indJobs += Int(tile.level) * Balance.jobsPerIndustrialLevel
            default:
                break
            }

            if tile.kind.consumesPower {
                consumerCount += 1
                if !tile.powered {
                    unpoweredCount += 1
                }
                if !tile.hasRoadAccess {
                    noRoadCount += 1
                }
            }
        }

        let totalJobs = comJobs + indJobs
        let taxPenalty = Double(city.taxRate - Balance.defaultTaxRate) * Balance.taxDemandFactor

        let rawRes = (Double(totalJobs) * 1.1 + 60.0 - Double(pop)) / 120.0 - taxPenalty
        let rawCom = (Double(pop) * 0.35 - Double(comJobs)) / 60.0 - taxPenalty
        let rawInd = (Double(pop) * 0.45 - Double(indJobs)) / 60.0 - taxPenalty

        city.stats.population = pop
        city.stats.commercialJobs = comJobs
        city.stats.industrialJobs = indJobs
        city.stats.resDemand = clamp(rawRes, min: -1.0, max: 1.0)
        city.stats.comDemand = clamp(rawCom, min: -1.0, max: 1.0)
        city.stats.indDemand = clamp(rawInd, min: -1.0, max: 1.0)
        city.stats.unpoweredCount = unpoweredCount
        city.stats.noRoadCount = noRoadCount
        city.stats.poweredRatio = consumerCount > 0
            ? Double(consumerCount - unpoweredCount) / Double(consumerCount)
            : 1.0
    }

    // MARK: - Zone Growth & Decline

    private static func stepZoneGrowth(city: City, rng: inout some RandomNumberGenerator) -> [GridPoint] {
        var zonePoints: [GridPoint] = []
        for y in 0..<city.map.height {
            for x in 0..<city.map.width {
                let p = GridPoint(x: x, y: y)
                if city.map[p].kind.isZone {
                    zonePoints.append(p)
                }
            }
        }
        guard !zonePoints.isEmpty else { return [] }

        let sampleCount = max(1, Int((Double(zonePoints.count) * Balance.growthSampleRatio).rounded()))
        let happinessFactor = 0.5 + city.stats.happiness / 100.0
        var changed: [GridPoint] = []

        for i in 0..<sampleCount {
            let pickIndex = Int.random(in: i..<zonePoints.count, using: &rng)
            zonePoints.swapAt(i, pickIndex)
            let p = zonePoints[i]
            var tile = city.map[p]

            let demand: Double
            let maxLevel: UInt8
            switch tile.kind {
            case .residential:
                demand = city.stats.resDemand
                let d = city.desirability(at: p)
                if d < 40 {
                    maxLevel = 1
                } else if d < 65 {
                    maxLevel = 2
                } else {
                    maxLevel = 3
                }
            case .commercial:
                demand = city.stats.comDemand
                maxLevel = 3
            case .industrial:
                demand = city.stats.indDemand
                maxLevel = 3
            default:
                continue
            }

            if tile.powered && tile.hasRoadAccess && demand > 0 && tile.level < maxLevel {
                let growProb = Balance.growthProbabilityFactor * demand * happinessFactor
                if Double.random(in: 0..<1, using: &rng) < growProb {
                    tile.level += 1
                    city.map[p] = tile
                    changed.append(p)
                }
            } else if tile.level > 0 && (!tile.powered || !tile.hasRoadAccess || demand < Balance.declineDemandThreshold) {
                if Double.random(in: 0..<1, using: &rng) < Balance.declineProbability {
                    tile.level -= 1
                    city.map[p] = tile
                    changed.append(p)
                }
            }
        }

        return changed
    }

    // MARK: - Happiness

    private static func updateHappiness(city: City) {
        var resCount = 0
        var poweredResCount = 0
        var totalResDesirability = 0
        var schoolCount = 0
        var hospitalCount = 0

        for y in 0..<city.map.height {
            for x in 0..<city.map.width {
                let p = GridPoint(x: x, y: y)
                let tile = city.map[p]
                switch tile.kind {
                case .residential:
                    resCount += 1
                    if tile.powered { poweredResCount += 1 }
                    totalResDesirability += city.desirability(at: p)
                case .school:
                    schoolCount += 1
                case .hospital:
                    hospitalCount += 1
                default:
                    break
                }
            }
        }

        var target = 50.0

        let resPowerRatio = resCount > 0 ? Double(poweredResCount) / Double(resCount) : 1.0
        if resPowerRatio >= 0.95 {
            target += 15.0
        }

        let avgResDesirability = resCount > 0
            ? Double(totalResDesirability) / Double(resCount)
            : Double(Balance.baseDesirability)
        target += clamp(avgResDesirability - 50.0, min: -20.0, max: 20.0)

        if schoolCount >= 1 {
            target += 10.0
        }
        if hospitalCount >= 1 && city.stats.population > 200 {
            target += 10.0
        }

        target -= Double(city.taxRate - Balance.defaultTaxRate) * 3.0

        if Double(city.stats.population) * 0.6 > Double(city.stats.jobs) {
            target -= 10.0
        }

        let clampedTarget = clamp(target, min: 0.0, max: 100.0)
        let alpha = Balance.happinessSmoothing
        city.stats.happiness = city.stats.happiness * (1.0 - alpha) + clampedTarget * alpha
    }

    private static func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        Swift.max(lower, Swift.min(upper, value))
    }
}
