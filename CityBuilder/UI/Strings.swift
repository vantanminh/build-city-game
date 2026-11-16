import CityCore
import Foundation

enum L10n {
    static let appTitle = "Thành Phố Của Tôi"
    static let defaultCityName = "Thành Phố Mới"
    static let newSeedButton = "Bản đồ mới"
    static let notEnoughMoney = "Không đủ tiền"
    static let freeLabel = "Miễn phí"
    static let settingsTitle = "Cài đặt & Tài chính"
    static let taxSectionTitle = "Thuế suất"
    static let budgetSectionTitle = "Ngân sách hàng tháng (ước tính)"
    static let incomeLabel = "Thu thuế"
    static let expensesLabel = "Chi phí bảo trì"
    static let netLabel = "Cân đối"
    static let chartSectionTitle = "Lịch sử 24 tháng"
    static let noHistoryYet = "Chưa có dữ liệu tháng nào. Hãy chạy mô phỏng hết tháng đầu tiên."
    static let cityActionsTitle = "Quản lý thành phố"
    static let newCityConfirmTitle = "Tạo thành phố mới?"
    static let newCityConfirmMessage = "Thành phố hiện tại chưa lưu sẽ bị thay thế."
    static let newCityConfirmAction = "Tạo mới"
    static let cancelLabel = "Huỷ"
    static let closeLabel = "Đóng"
    static let aboutSectionTitle = "Giới thiệu"
    static let aboutDescription = "Thành Phố Của Tôi v1.0.0 — Game xây thành phố mã nguồn mở (MIT), đồ hoạ isometric vẽ hoàn toàn bằng code."
    static let bankruptTitle = "Thành phố phá sản"
    static let bankruptMessage = "Ngân quỹ dưới -$5.000 trong 3 tháng liên tiếp. Bạn có muốn bắt đầu thành phố mới không?"
    static let playAgainLabel = "Chơi lại"
    static let inspectLevel = "Cấp độ"
    static let inspectPower = "Điện"
    static let inspectRoad = "Đường bộ"
    static let inspectDesirability = "Hấp dẫn"
    static let poweredYes = "Có điện"
    static let poweredNo = "Thiếu điện"
    static let roadYes = "Có đường"
    static let roadNo = "Thiếu đường"
    static let notApplicable = "—"

    static func dateLabel(month: Int, year: Int) -> String {
        "Th \(month) · Năm \(year)"
    }

    static func milestoneToast(_ label: String) -> String {
        "Cột mốc mới: \(label)!"
    }

    static func warningNegativeMoney() -> String {
        "Ngân sách đang âm"
    }

    static func warningUnpowered(_ count: Int) -> String {
        "\(count) ô thiếu điện"
    }

    static func warningNoRoad(_ count: Int) -> String {
        "\(count) ô thiếu đường"
    }

    static func toolName(_ tool: Tool) -> String {
        switch tool {
        case .inspect: return "Xem"
        case .road: return "Đường"
        case .residential: return "Dân cư"
        case .commercial: return "Thương mại"
        case .industrial: return "Công nghiệp"
        case .park: return "Công viên"
        case .powerPlant: return "Điện"
        case .school: return "Trường học"
        case .hospital: return "Bệnh viện"
        case .bulldoze: return "Phá bỏ"
        }
    }

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
