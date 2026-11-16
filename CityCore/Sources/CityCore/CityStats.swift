import Foundation

/// Aggregated metrics for HUD display and simulation feedback.
public struct CityStats: Codable, Equatable, Sendable {
    public var population: Int
    public var commercialJobs: Int
    public var industrialJobs: Int
    public var resDemand: Double
    public var comDemand: Double
    public var indDemand: Double
    public var happiness: Double
    public var poweredRatio: Double
    public var unpoweredCount: Int
    public var noRoadCount: Int

    public var jobs: Int {
        commercialJobs + industrialJobs
    }

    public init(
        population: Int = 0,
        commercialJobs: Int = 0,
        industrialJobs: Int = 0,
        resDemand: Double = 0.5,
        comDemand: Double = 0,
        indDemand: Double = 0,
        happiness: Double = 50,
        poweredRatio: Double = 1,
        unpoweredCount: Int = 0,
        noRoadCount: Int = 0
    ) {
        self.population = population
        self.commercialJobs = commercialJobs
        self.industrialJobs = industrialJobs
        self.resDemand = resDemand
        self.comDemand = comDemand
        self.indDemand = indDemand
        self.happiness = happiness
        self.poweredRatio = poweredRatio
        self.unpoweredCount = unpoweredCount
        self.noRoadCount = noRoadCount
    }
}

/// Snapshot of one closed game month for financial charts.
public struct MonthRecord: Codable, Equatable, Sendable {
    public var year: Int
    public var month: Int
    public var income: Int
    public var expenses: Int
    public var population: Int
    public var endingMoney: Int

    public init(
        year: Int,
        month: Int,
        income: Int,
        expenses: Int,
        population: Int,
        endingMoney: Int
    ) {
        self.year = year
        self.month = month
        self.income = income
        self.expenses = expenses
        self.population = population
        self.endingMoney = endingMoney
    }
}
