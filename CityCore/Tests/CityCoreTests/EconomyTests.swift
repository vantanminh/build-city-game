import XCTest
@testable import CityCore

final class EconomyTests: XCTestCase {
    func testMonthlyBudgetFormulaAndSettlement() {
        var map = CityMap(width: 10, height: 10)
        // Pop = 40 * 25 = 1000 (10 R tiles at L3 -> 750 + 5 R tiles at L2 -> 250)
        for x in 0..<10 {
            map[GridPoint(x: x, y: 0)] = Tile(kind: .residential, level: 3)
        }
        for x in 0..<5 {
            map[GridPoint(x: x, y: 1)] = Tile(kind: .residential, level: 2)
        }
        // Jobs = 500: 10 C at L2 (300) + 5 I at L2 (200)
        for x in 0..<10 {
            map[GridPoint(x: x, y: 2)] = Tile(kind: .commercial, level: 2)
        }
        for x in 0..<5 {
            map[GridPoint(x: x, y: 3)] = Tile(kind: .industrial, level: 2)
        }
        // Upkeep structures: 10 roads (10), 1 powerPlant (60), 1 school (40), 1 hospital (50), 2 parks (6) -> 166
        for x in 0..<10 {
            map[GridPoint(x: x, y: 4)] = Tile(kind: .road)
        }
        map[GridPoint(x: 0, y: 5)] = Tile(kind: .powerPlant)
        map[GridPoint(x: 1, y: 5)] = Tile(kind: .school)
        map[GridPoint(x: 2, y: 5)] = Tile(kind: .hospital)
        map[GridPoint(x: 3, y: 5)] = Tile(kind: .park)
        map[GridPoint(x: 4, y: 5)] = Tile(kind: .park)

        let city = City(name: "Econ", map: map, money: 1_000, taxRate: 9)
        Simulation.recomputeStats(city: city)

        // income = 1000 * 0.09 * 1.6 + 500 * 0.09 * 1.2 = 144 + 54 = 198
        // expenses = 10 + 60 + 40 + 50 + 6 = 166
        let budget = Economy.estimateMonthlyBudget(for: city)
        XCTAssertEqual(budget.income, 198)
        XCTAssertEqual(budget.expenses, 166)
        XCTAssertEqual(budget.net, 32)

        let events = Economy.closeMonth(city: city, year: 1, month: 1)
        XCTAssertEqual(events, [.monthEnded(income: 198, expenses: 166)])
        XCTAssertEqual(city.money, 1_032)
        XCTAssertEqual(city.history.count, 1)
        XCTAssertEqual(city.history.first, MonthRecord(year: 1, month: 1, income: 198, expenses: 166, population: 1_000, endingMoney: 1_032))
    }

    func testHistoryIsCappedAt24Months() {
        let city = City(name: "Hist", map: CityMap(width: 6, height: 6), money: 10_000)
        for m in 1...30 {
            _ = Economy.closeMonth(city: city, year: 1 + (m - 1) / 12, month: ((m - 1) % 12) + 1)
        }
        XCTAssertEqual(city.history.count, Balance.maxHistoryMonths)
        XCTAssertEqual(city.history.first?.month, 7)
        XCTAssertEqual(city.history.last?.year, 3)
        XCTAssertEqual(city.history.last?.month, 6)
    }

    func testBankruptcyTriggersAfterThreeConsecutiveMonthsBelowThreshold() {
        var map = CityMap(width: 6, height: 6)
        map[GridPoint(x: 0, y: 0)] = Tile(kind: .powerPlant) // 60/month expense, 0 income
        let city = City(name: "Bankrupt", map: map, money: -5_100)
        Simulation.recomputeStats(city: city)

        let m1 = Economy.closeMonth(city: city, year: 1, month: 1)
        XCTAssertFalse(m1.contains(.bankrupt))

        let m2 = Economy.closeMonth(city: city, year: 1, month: 2)
        XCTAssertFalse(m2.contains(.bankrupt))

        let m3 = Economy.closeMonth(city: city, year: 1, month: 3)
        XCTAssertTrue(m3.contains(.bankrupt))
    }

    func testBankruptcyStreakResetsWhenMoneyRecovers() {
        var map = CityMap(width: 6, height: 6)
        map[GridPoint(x: 0, y: 0)] = Tile(kind: .powerPlant)
        let city = City(name: "Recover", map: map, money: -5_100)
        Simulation.recomputeStats(city: city)

        _ = Economy.closeMonth(city: city, year: 1, month: 1)
        _ = Economy.closeMonth(city: city, year: 1, month: 2)
        city.money = 500
        let m3 = Economy.closeMonth(city: city, year: 1, month: 3)
        XCTAssertFalse(m3.contains(.bankrupt))

        city.money = -5_100
        let m4 = Economy.closeMonth(city: city, year: 1, month: 4)
        XCTAssertFalse(m4.contains(.bankrupt))
    }

    func testMilestonesFireOncePerThreshold() {
        var map = CityMap(width: 8, height: 8)
        map[GridPoint(x: 0, y: 0)] = Tile(kind: .residential, level: 3) // 75
        map[GridPoint(x: 1, y: 0)] = Tile(kind: .residential, level: 1) // +25 = 100
        let city = City(name: "Mile", map: map)
        Simulation.recomputeStats(city: city)

        let first = Economy.evaluateMilestones(city: city)
        XCTAssertEqual(first, [.milestone("Làng (100 dân)")])

        let second = Economy.evaluateMilestones(city: city)
        XCTAssertTrue(second.isEmpty)
    }
}
