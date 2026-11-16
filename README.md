# Thành Phố Của Tôi (CityBuilder)

Game xây thành phố isometric 2.5D mã nguồn mở cho **iOS 16+** (iPhone & iPad), xây dựng bằng **SwiftUI**, **SpriteKit** và Swift Package thuần `Foundation` (`CityCore`). Mọi đồ hoạ công trình, địa hình và icon ứng dụng đều được vẽ hoàn toàn bằng code, không dùng thư viện bên thứ ba hay tài nguyên có bản quyền.

## Tính năng
- **Bản đồ isometric 48×48 tất định theo seed**: hồ nước hoặc sông uốn lượn, cụm rừng và vùng trung tâm trống để khởi đầu.
- **10 công cụ quy hoạch**: Xem thông tin ô (`inspect`), Đường tự nối 16 hướng (`road`), Khu Dân cư / Thương mại / Công nghiệp (`R/C/I` phát triển L0→L3), Công viên, Nhà máy điện, Trường học, Bệnh viện và Máy ủi (`bulldoze`).
- **Thao tác cảm ứng tự nhiên**: chạm hoặc kéo để vẽ liên tục (nội suy 4 hướng, không đứt nét), kéo 1–2 ngón để di chuyển camera, chụm 2 ngón để thu phóng, kèm phản hồi rung (haptic) và thông báo toast.
- **Mô phỏng đô thị**:
  - Truy cập đường (Chebyshev ≤ 2) và lưới điện BFS 4 hướng (80 ô tiêu thụ mỗi nhà máy, cảnh báo ⚡ nhấp nháy khi thiếu điện).
  - Nhu cầu R/C/I, độ hấp dẫn đất (`desirability`), hạnh phúc cư dân, 4 mức tốc độ thời gian (`⏸ / 1× / 3× / 10×`).
- **Kinh tế & tài chính**: thu thuế & chi phí bảo trì cuối mỗi tháng, tuỳ chỉnh thuế suất 0–20%, biểu đồ thu/chi 24 tháng, cột mốc dân số và cảnh báo phá sản.
- **Lưu & tải tự động**: lưu JSON có phiên bản (`SaveGame v1`), ghi atomic vào `Documents/city.json`, tự động lưu mỗi cuối tháng và khi vào nền, kèm màn hình khởi động Tiếp tục / Thành phố mới.

## Kiến trúc
- [`CityCore/`](CityCore/Package.swift): Swift Package chỉ `import Foundation` chứa toàn bộ model, địa hình, lưới điện, mô phỏng, kinh tế và bộ unit test (`swift test`).
- [`CityBuilder/`](CityBuilder/): ứng dụng iOS dùng SwiftUI cho HUD/sheet và SpriteKit cho bản đồ isometric (`TextureFactory` vẽ bằng `UIGraphicsImageRenderer`).
- [`project.yml`](project.yml): đặc tả XcodeGen để sinh `CityBuilder.xcodeproj` trong CI (không commit `.xcodeproj`).
- [`scripts/make_icon.swift`](scripts/make_icon.swift): sinh `icon-1024.png` không kênh alpha tự động trong quá trình CI.

## Build & kiểm thử qua GitHub Actions
Dự án sử dụng workflow [`.github/workflows/ci.yml`](.github/workflows/ci.yml) chạy trên `macos-15`:
1. **`core-tests`**: chạy `swift test` trong `CityCore/`.
2. **`build-ios`**: chạy `make_icon.swift`, sinh `CityBuilder.xcodeproj` bằng `xcodegen generate`, build cho `generic/platform=iOS Simulator` và `generic/platform=iOS` (unsigned), rồi tải lên artifact `CityBuilder-<sha>` gồm:
   - `CityBuilder-unsigned.ipa`
   - `CityBuilder-simulator.zip`

Nếu có máy Mac (hoặc cài XcodeGen + Xcode 16+):
```bash
cd CityCore && swift test && cd ..
swift scripts/make_icon.swift CityBuilder/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
xcodegen generate
open CityBuilder.xcodeproj
```

## Cách cài đặt IPA unsigned lên iPhone / iPad
Tệp `CityBuilder-unsigned.ipa` (tải từ tab **Actions** hoặc trang **Releases**) chưa được ký bởi Apple Developer, nên cần công cụ sideload miễn phí bằng Apple ID cá nhân:

1. **AltStore / SideStore** *(khuyến nghị)*
   - Cài AltStore (qua máy tính Windows/macOS) hoặc SideStore trên iPhone/iPad.
   - Mở tệp `CityBuilder-unsigned.ipa` bằng AltStore/SideStore để tự ký và cài đặt (ký lại mỗi 7 ngày).
2. **Sideloadly** *(Windows / macOS)*
   - Kết nối iPhone/iPad với máy tính, kéo thả `CityBuilder-unsigned.ipa` vào Sideloadly, nhập Apple ID và nhấn **Start**.
3. **Trình giả lập iOS (macOS có Xcode)**
   - Giải nén `CityBuilder-simulator.zip` để lấy `CityBuilder.app`, sau đó chạy:
     ```bash
     xcrun simctl install booted CityBuilder.app
     ```

## Đưa app lên TestFlight (nếu có tài khoản Apple Developer)
Xem hướng dẫn từng bước từ máy Windows (không cần Mac) tại [docs/testflight-setup.md](docs/testflight-setup.md) và workflow [`.github/workflows/testflight.yml`](.github/workflows/testflight.yml).

## Đóng góp
Xem hướng dẫn tại [CONTRIBUTING.md](CONTRIBUTING.md). Rất hoan nghênh bug report, đề xuất tính năng và Pull Request!

## Giấy phép
Phát hành theo giấy phép [MIT](LICENSE).
