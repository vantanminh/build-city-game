import Foundation

/// Calendar state for the simulation (30 days/month, 12 months/year).
public struct GameDate: Codable, Equatable, Hashable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int = 1, month: Int = 1, day: Int = 1) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Advances the calendar by 1 day and returns `true` if a month boundary just completed.
    @discardableResult
    public mutating func advanceDay() -> Bool {
        day += 1
        if day > Balance.daysPerMonth {
            day = 1
            month += 1
            if month > Balance.monthsPerYear {
                month = 1
                year += 1
            }
            return true
        }
        return false
    }
}
