# 05 — Quy ước & cách làm việc

## 1. Làm việc khi không có Mac
Vì không chạy được Xcode local, vòng lặp phát triển là:
1. Viết code cẩn thận, ưu tiên API ổn định, quen thuộc (SwiftUI/SpriteKit iOS 16).
2. **Logic thuần nằm trong CityCore** → kiểm tra nhanh:
   - Trên Windows (tuỳ chọn, rất nên): cài Swift toolchain `winget install --id Swift.Toolchain` (cần Visual Studio Build Tools theo hướng dẫn swift.org), rồi `cd CityCore; swift build; swift test`.
   - Hoặc để CI job `core-tests` chạy.
3. Commit nhỏ, push, theo dõi `gh run watch`. Nếu đỏ: `gh run view <id> --log-failed`, sửa đúng dòng `error:`, push lại.
4. **Không** đánh dấu task xong khi CI chưa xanh.

## 2. Swift
- Swift language mode 5 (`SWIFT_VERSION = 5.0`; trong `Package.swift` dùng `swift-tools-version:5.9` và không bật `StrictConcurrency`).
- CityCore: chỉ `import Foundation`. Không dùng API chỉ có trên Apple (ví dụ `CoreGraphics`) để còn build được trên Windows/Linux.
- Kiểu public của CityCore phải có `public` và `public init` rõ ràng (struct public không tự có memberwise init public).
- Tránh `!` force-unwrap, tránh `fatalError` trong đường chạy bình thường.
- `@MainActor` cho `GameController` và mọi thứ đụng SpriteKit/UIKit.
- Đặt tên: kiểu `UpperCamelCase`, hàm/biến `lowerCamelCase`, file trùng tên kiểu chính.
- Hằng số cân bằng game chỉ ở `Balance.swift`.
- Comment bằng tiếng Anh hoặc tiếng Việt đều được, nhưng **nhất quán trong một file**. Chuỗi hiển thị cho người dùng: tiếng Việt, gom vào `Strings.swift` (enum `L10n`) để sau này dễ chuyển sang String Catalog.

## 3. Git
- Nhánh chính `main`. Mỗi milestone có thể làm trên nhánh `m1-core`, `m2-render`… và merge khi CI xanh (hoặc commit thẳng `main` nếu làm một mình — hỏi người dùng thích kiểu nào).
- Commit message dạng Conventional Commits: `feat(core): power grid BFS`, `fix(ci): ...`, `docs: ...`.
- **Commit sau mỗi slice nhỏ hoàn chỉnh** (quy tắc harness), chỉ `git add` file của slice đó.
- **Push**: vì CI là trình biên dịch duy nhất, sau khi người dùng đã xác nhận tạo repo GitHub, agent được phép push lên repo đó để chạy CI. Không force-push, không push sang remote khác.
- Không commit: `*.xcodeproj`, `build/`, `.build/`, `*.ipa`, `.5harness/` (phần local/index), secrets, file cá nhân.

## 3b. Harness (5harness)
- Dự án đã được `harness init` (project id trong `AGENTS.md`). Đọc `.agents/skills/harness/SKILL.md` cho vòng làm việc.
- Mở đầu phiên: `harness doctor --json`, `harness status --json`, `harness next --json`.
- **Không sửa tay** file trong `docs/stories/`, `docs/decisions/`, `docs/intakes/`, `docs/backlog/`, `docs/reports/` — chỉ qua CLI `harness …`.
- Lệnh harness lỗi (exit ≠ 0) → **dừng**, chạy `harness doctor` / `harness link` / `harness reindex`, rồi thử lại. Không lách bằng cách sửa markdown.
- Quyết định kiến trúc mới → `harness decision add --id DEC-00X --title "…" --status accepted --links <file>`.
- Ý tưởng ngoài phạm vi → `harness backlog add --title "…" --pain "…"`.
- Không bịa flag: chạy `harness <lệnh> --help` khi không chắc.

## 4. An toàn & bản quyền
- Không sao chép tên, đồ hoạ, âm thanh, giao diện của game thương mại. Mọi hình ảnh vẽ bằng code.
- Nếu thêm font/âm thanh: chỉ CC0 hoặc license tương thích MIT, ghi nguồn trong `CREDITS.md`.
- Không đưa email/thông tin cá nhân của người dùng vào code, commit config công khai hoặc README nếu chưa được đồng ý.

## 5. Những hành động phải hỏi người dùng trước
- Tạo repo GitHub, đặt public/private, push lần đầu.
- Đổi `bundleIdPrefix` (cần username GitHub của người dùng).
- Tạo tag / GitHub Release.
- Thêm bất kỳ secret nào hoặc dịch vụ trả phí.
- Xoá/ghi đè file không do agent tạo.
