import Foundation

/// Projected monthly tax revenue and municipal upkeep breakdown.
public struct MonthlyBudget: Equatable, Sendable {
    public let income: Int
    public let expenses: Int
    public var net: Int { income - expenses }

    public init(income: Int, expenses: Int) {
        self.income = income
        self.expenses = expenses
    }
}

/// Monthly tax collection, infrastructure upkeep, financial history, and bankruptcy rules.
public enum Economy {
    /// Computes expected monthly income and expenses without mutating `city`.
    public static func estimateMonthlyBudget(for city: City) -> MonthlyBudget {
        let rate = Double(city.taxRate) / 100.0
        let rawIncome =
            Double(city.stats.population) * rate * Balance.populationTaxMultiplier +
            Double(city.stats.jobs) * rate * Balance.jobsTaxMultiplier
        let income = Int(rawIncome.rounded())

        var roads = 0
        var powerPlants = 0
        var schools = 0
        var hospitals = 0
        var parks = 0

        for tile in city.map.tiles {
            switch tile.kind {
            case .road: roads += 1
            case .powerPlant: powerPlants += 1
            case .school: schools += 1
            case .hospital: hospitals += 1
            case .park: parks += 1
            default: break
            }
        }

        let expenses =
            roads * Balance.roadUpkeep +
            powerPlants * Balance.powerPlantUpkeep +
            schools * Balance.schoolUpkeep +
            hospitals * Balance.hospitalUpkeep +
            parks * Balance.parkUpkeep

        return MonthlyBudget(income: income, expenses: expenses)
    }

    /// Closes a completed game month, updating treasury, 24-month history, and bankruptcy state.
    @discardableResult
    public static func closeMonth(city: City, year: Int, month: Int) -> [CityEvent] {
        let budget = estimateMonthlyBudget(for: city)
        city.money += budget.net

        let record = MonthRecord(
            year: year,
            month: month,
            income: budget.income,
            expenses: budget.expenses,
            population: city.stats.population,
            endingMoney: city.money
        )
        city.history.append(record)
        if city.history.count > Balance.maxHistoryMonths {
            city.history.removeFirst(city.history.count - Balance.maxHistoryMonths)
        }

        var events: [CityEvent] = [
            .monthEnded(income: budget.income, expenses: budget.expenses)
        ]

        if city.money < Balance.bankruptcyMoneyThreshold {
            city.negativeBankruptcyMonths += 1
            if city.negativeBankruptcyMonths >= Balance.bankruptcyConsecutiveMonths {
                events.append(.bankrupt)
            }
        } else {
            city.negativeBankruptcyMonths = 0
        }

        return events
    }

    /// Evaluates newly crossed population milestones and returns their event notifications.
    public static func evaluateMilestones(city: City) -> [CityEvent] {
        let labels: [(Int, String)] = [
            (100, "Làng (100 dân)"),
            (500, "Thị trấn (500 dân)"),
            (1_000, "Thị xã (1.000 dân)"),
            (5_000, "Thành phố (5.000 dân)"),
            (10_000, "Đô thị lớn (10.000 dân)")
        ]

        var events: [CityEvent] = []
        for (threshold, label) in labels {
            if city.stats.population >= threshold && !city.triggeredMilestones.contains(threshold) {
                city.triggeredMilestones.insert(threshold)
                events.append(.milestone(label))
            }
        }
        return events
    }
}
