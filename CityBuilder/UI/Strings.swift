import CityCore
import Foundation

enum L10n {
    static let appTitle = "Thành Phố Của Tôi"
    static let defaultCityName = "Thành Phố Mới"
    static let newSeedButton = "Bản đồ mới"

    static func tileKindName(_ kind: TileKind) -> String {
        switch kind {
        case .grass: return "Đất trống"
        case .water: return "Mặt nước"
        case .forest: return "Rừng cây"
        case .road: return "Đường phố"
        case .residential: return "Khu dân cư"
        case .commercial: return "Khu thương mại"
        case .industrial: return "Khu công nghiệp"
        case .park: return "Công viên"
        case .powerPlant: return "Nhà máy điện"
        case .school: return "Trường học"
        case .hospital: return "Bệnh viện"
        }
    }
}
