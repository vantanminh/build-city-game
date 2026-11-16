import Foundation

/// Player interaction tools available in the build toolbar.
public enum Tool: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case inspect
    case road
    case residential
    case commercial
    case industrial
    case park
    case powerPlant
    case school
    case hospital
    case bulldoze

    /// Base placement cost before any terrain clearing surcharges.
    public var cost: Int {
        switch self {
        case .inspect: return 0
        case .road: return Balance.roadCost
        case .residential, .commercial, .industrial: return Balance.zoneCost
        case .park: return Balance.parkCost
        case .powerPlant: return Balance.powerPlantCost
        case .school: return Balance.schoolCost
        case .hospital: return Balance.hospitalCost
        case .bulldoze: return Balance.bulldozeCost
        }
    }

    /// Tile kind produced by applying this tool, or `nil` for `inspect`.
    public var resultingKind: TileKind? {
        switch self {
        case .inspect: return nil
        case .road: return .road
        case .residential: return .residential
        case .commercial: return .commercial
        case .industrial: return .industrial
        case .park: return .park
        case .powerPlant: return .powerPlant
        case .school: return .school
        case .hospital: return .hospital
        case .bulldoze: return .grass
        }
    }
}
