# Đóng góp cho Thành Phố Của Tôi (CityBuilder)

Cảm ơn bạn đã quan tâm đóng góp cho dự án!

## Quy tắc kỹ thuật
1. **Giữ `CityCore` thuần `Foundation`**: mọi luật chơi, tính toán mô phỏng và kinh tế đặt trong `CityCore/` (không import `UIKit`, `SpriteKit`, `SwiftUI` hay `CoreGraphics`) và phải có unit test trong `CityCore/Tests/CityCoreTests/`.
2. **Swift 5 mode & iOS 16+**: không dùng thư viện bên thứ ba, không bật strict concurrency Swift 6, tránh force-unwrap (`!`) và `fatalError` trên đường chạy bình thường.
3. **Không commit file sinh tự động**: không commit `*.xcodeproj`, `build/`, `.build/`, `*.ipa`, hoặc `icon-1024.png`. Project Xcode được sinh từ `project.yml` bằng XcodeGen.
4. **Đồ hoạ nguyên bản**: mọi hình ảnh/icon phải vẽ bằng code (`TextureFactory`, `scripts/make_icon.swift`); không sao chép tài nguyên từ game thương mại.
5. **Commit theo Conventional Commits**: ví dụ `feat(core): ...`, `fix(ui): ...`, `docs: ...`.

## Kiểm tra trước khi mở Pull Request
- Nếu dùng macOS/Windows có Swift toolchain: chạy `cd CityCore && swift test`.
- Trên GitHub: mọi PR sẽ tự động chạy CI (`core-tests` và `build-ios` trên `macos-15`). PR chỉ được merge khi cả hai job xanh.
