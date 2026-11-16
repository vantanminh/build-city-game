import Foundation

/// Central tuning constants for city simulation, economy, and map generation.
public enum Balance {
    // MARK: - Map & Terrain
    public static let defaultMapSize: Int = 48
    public static let centerClearRadius: Int = 6
    public static let forestMinRatio: Double = 0.12
    public static let forestMaxRatio: Double = 0.18

    // MARK: - Tool Costs
    public static let roadCost: Int = 10
    public static let zoneCost: Int = 20
    public static let parkCost: Int = 100
    public static let powerPlantCost: Int = 3000
    public static let schoolCost: Int = 1500
    public static let hospitalCost: Int = 2000
    public static let bulldozeCost: Int = 5
    public static let forestClearCost: Int = 10

    // MARK: - Time
    public static let daysPerMonth: Int = 30
    public static let monthsPerYear: Int = 12

    // MARK: - Road & Power
    public static let roadAccessRadius: Int = 2
    public static let powerPlantCapacity: Int = 80
    public static let powerRecomputeInterval: Int = 10

    // MARK: - Population & Jobs
    public static let populationPerResidentialLevel: Int = 25
    public static let jobsPerCommercialLevel: Int = 15
    public static let jobsPerIndustrialLevel: Int = 20

    // MARK: - Demand & Tax
    public static let defaultTaxRate: Int = 9
    public static let minTaxRate: Int = 0
    public static let maxTaxRate: Int = 20
    public static let taxDemandFactor: Double = 0.03

    // MARK: - Desirability
    public static let baseDesirability: Int = 50
    public static let parkDesirabilityRadius: Int = 4
    public static let parkDesirabilityBonus: Int = 8
    public static let parkDesirabilityMaxBonus: Int = 24
    public static let schoolDesirabilityRadius: Int = 8
    public static let schoolDesirabilityBonus: Int = 10
    public static let hospitalDesirabilityRadius: Int = 8
    public static let hospitalDesirabilityBonus: Int = 10
    public static let waterDesirabilityRadius: Int = 2
    public static let waterDesirabilityBonus: Int = 6
    public static let forestDesirabilityRadius: Int = 2
    public static let forestDesirabilityBonus: Int = 3
    public static let industrialDesirabilityRadius: Int = 4
    public static let industrialDesirabilityPenalty: Int = -6
    public static let industrialDesirabilityMaxPenalty: Int = -30
    public static let powerPlantDesirabilityRadius: Int = 5
    public static let powerPlantDesirabilityPenalty: Int = -15

    // MARK: - Growth & Happiness
    public static let growthSampleRatio: Double = 0.10
    public static let growthProbabilityFactor: Double = 0.25
    public static let declineProbability: Double = 0.15
    public static let declineDemandThreshold: Double = -0.4
    public static let happinessSmoothing: Double = 0.1

    // MARK: - Economy
    public static let startingMoney: Int = 20_000
    public static let bankruptcyMoneyThreshold: Int = -5_000
    public static let bankruptcyConsecutiveMonths: Int = 3
    public static let maxHistoryMonths: Int = 24
    public static let populationTaxMultiplier: Double = 1.6
    public static let jobsTaxMultiplier: Double = 1.2
    public static let roadUpkeep: Int = 1
    public static let powerPlantUpkeep: Int = 60
    public static let schoolUpkeep: Int = 40
    public static let hospitalUpkeep: Int = 50
    public static let parkUpkeep: Int = 3

    // MARK: - Milestones
    public static let populationMilestones: [Int] = [100, 500, 1_000, 5_000, 10_000]
}
