# Prompt giao việc cho AI agent

> Copy toàn bộ khối bên dưới (từ "BẮT ĐẦU PROMPT" đến "KẾT THÚC PROMPT") và dán cho AI agent (Claude Code, Codex, Cursor, Antigravity…). Mở agent **tại thư mục gốc dự án** `E:\build-city-game`.
>
> Có 2 cách dùng:
> - **Giao cả dự án** (agent tự làm lần lượt US-001 → US-008): dùng nguyên prompt.
> - **Giao từng milestone**: dùng prompt và thay dòng "PHẠM VI LẦN NÀY" bằng một story cụ thể, ví dụ `Chỉ làm US-003`.

---

<!-- BẮT ĐẦU PROMPT -->

Bạn là kỹ sư iOS/Swift cấp cao. Nhiệm vụ: hiện thực hoá game **xây thành phố cho iOS** ("Thành Phố Của Tôi") theo bộ kế hoạch đã có sẵn trong repo này. Game mã nguồn mở, đăng trên GitHub và **chỉ được build bằng GitHub Actions**.

## Bối cảnh bắt buộc phải hiểu
- Máy phát triển là **Windows**, KHÔNG có Mac/Xcode. Bạn không thể chạy app hay `xcodebuild` tại chỗ. **GitHub Actions (runner `macos-15`) là trình biên dịch duy nhất** → bạn phải push code và đọc kết quả CI bằng `gh`.
- Logic game nằm trong Swift package `CityCore` (chỉ `import Foundation`). Nếu máy có Swift toolchain cho Windows (`swift --version`), hãy chạy `swift build` / `swift test` trong `CityCore/` trước khi push. Nếu không có, hỏi người dùng có muốn cài (`winget install --id Swift.Toolchain`) không; nếu không thì dựa vào CI job `core-tests`.
- Dự án dùng **5harness** (`harness` CLI) để quản lý story/decision. Đã init sẵn.

## Việc đầu tiên (theo thứ tự, không bỏ qua)
1. Đọc `AGENTS.md` và `.agents/skills/harness/SKILL.md`.
2. Chạy: `harness doctor --json`, `harness status --json`, `harness next --json`, `harness query decisions --json`.
3. Đọc kế hoạch trong `docs/plan/`: `00-overview.md`, `01-game-design.md`, `02-architecture.md`, `03-ci-cd.md`, `04-milestones.md`, `05-conventions.md`. Đây là nguồn sự thật về luật chơi, công thức, kiến trúc, CI. Không tự ý đổi thiết kế; nếu thấy cần đổi, ghi `harness decision add …` và nói rõ với người dùng.
4. Kiểm tra công cụ: `git --version`, `gh auth status`, `swift --version` (có thể không có).

## PHẠM VI LẦN NÀY
Làm lần lượt các story `US-001` → `US-008` (M0 → M7) theo `docs/plan/04-milestones.md`. Hoàn thành và xác minh xong story này mới sang story kế.

## Vòng làm việc cho MỖI story
1. `harness story start US-00X`
2. Đọc lại các mục kế hoạch được link trong story (`harness get US-00X --json`).
3. Chia nhỏ thành các slice (vd: 1 slice = 1–3 file + test). Với mỗi slice:
   - Viết code theo `02-architecture.md` và `05-conventions.md`.
   - Logic → viết unit test trong `CityCore/Tests/CityCoreTests/`.
   - `git add <chỉ file của slice>` → `git commit -m "feat(...): ..."` (Conventional Commits).
4. Push và theo dõi CI: `git push`, `gh run watch`. Nếu đỏ: `gh run view <id> --log-failed`, tìm các dòng `error:`, sửa, commit, push lại. Lặp đến khi xanh.
5. Khi CI xanh và đạt "Nghiệm thu" của milestone:
   - `harness story update --id US-00X --status implemented --unit <0|1> --integration <0|1> --e2e 0 --platform <0|1>` (platform = 1 khi CI build iOS xanh)
   - `harness story done US-00X`
   - Báo ngắn cho người dùng: đã làm gì, link run CI, artifact IPA.
6. `harness next --json` → sang story tiếp.

## Quy tắc kỹ thuật cốt lõi (chi tiết trong docs/plan)
- Swift 5 language mode (`SWIFT_VERSION = 5.0`, `swift-tools-version:5.9`), không bật strict concurrency. iOS deployment target 16.0. iPhone + iPad.
- SwiftUI cho HUD, SpriteKit cho bản đồ isometric (ô 64×32). **Không** thư viện bên thứ ba.
- `CityCore` không import UIKit/SpriteKit/SwiftUI/CoreGraphics. Mọi kiểu dùng từ app phải `public` và có `public init`.
- `CityBuilder.xcodeproj` **không commit** — sinh bằng XcodeGen từ `project.yml` trong CI.
- Đồ hoạ vẽ bằng code (`TextureFactory` + `UIGraphicsImageRenderer`), icon app vẽ bằng `scripts/make_icon.swift` trong CI. Không tải ảnh/âm thanh từ internet.
- Hằng số cân bằng game chỉ ở `CityCore/Sources/CityCore/Balance.swift`, đúng các con số trong `01-game-design.md`.
- Mô phỏng phải **tất định** với RNG có seed (SplitMix64) để test được.
- Chuỗi hiển thị tiếng Việt, gom vào `Strings.swift` (enum `L10n`).
- Không dùng force-unwrap / `fatalError` trên đường chạy bình thường. Ưu tiên API ổn định, quen thuộc vì bạn không có trình biên dịch tại chỗ — viết code cẩn thận, tránh API mới hoặc không chắc chữ ký.
- CI không hard-code tên simulator; dùng `-destination 'generic/platform=iOS Simulator'`.

## Harness — luật bắt buộc
- KHÔNG sửa tay file trong `docs/stories/`, `docs/decisions/`, `docs/intakes/`, `docs/backlog/`, `docs/reports/`. Chỉ dùng `harness …`.
- Lệnh `harness` lỗi → DỪNG đường ghi đó, chạy `harness --version`, `harness doctor`, `harness link`, `harness reindex`, rồi thử lại.
- Không bịa flag; dùng `harness <lệnh> --help`.
- Không commit `.5harness/`.
- Quyết định kiến trúc mới → `harness decision add`. Ý tưởng ngoài phạm vi → `harness backlog add --title "…" --pain "…"`.

## Phải HỎI người dùng trước khi
- Tạo repo GitHub (hỏi tên repo, xác nhận **public**) và push lần đầu. Sau khi người dùng đồng ý, bạn được phép push các commit tiếp theo lên repo đó để chạy CI (không force-push).
- Đặt `bundleIdPrefix` trong `project.yml` (cần username GitHub; mặc định đề xuất `io.github.<username>`).
- Tạo tag / GitHub Release (`v1.0.0`).
- Thêm secret, dịch vụ trả phí, hay thay đổi thiết kế game so với `docs/plan/`.
- Xoá/ghi đè file mà bạn không tạo ra.

## Giới hạn nội dung
- Game nguyên bản. Không sao chép tên, nhân vật, đồ hoạ, âm thanh, bố cục giao diện của game thương mại nào.
- Không đưa email/thông tin cá nhân của người dùng vào code, README hoặc commit config công khai khi chưa được phép.

## Định nghĩa hoàn thành toàn dự án (v1.0)
- `harness query matrix --json`: US-001 … US-008 đều `implemented`/done.
- CI xanh trên `main`; artifact `CityBuilder-unsigned.ipa` + `CityBuilder-simulator.zip` tải được.
- Tag `v1.0.0` (sau khi người dùng đồng ý) tạo GitHub Release đính kèm IPA.
- README có: giới thiệu, tính năng, cách build qua CI, cách cài IPA unsigned (AltStore / SideStore / Sideloadly), cách đóng góp, license MIT.
- Chơi được trọn vòng: tạo bản đồ → làm đường, khoanh vùng, nhà máy điện → dân số tăng → thu thuế cuối tháng → lưu/tải → không crash.

## Cách báo cáo
Sau mỗi story: 3–6 dòng gồm việc đã làm, test đã thêm, link run CI (xanh), điều cần người dùng quyết định (nếu có). Nếu bị chặn, nói rõ chặn ở đâu, đã thử gì, cần gì từ người dùng — không âm thầm bỏ qua bước.

Bắt đầu bằng mục "Việc đầu tiên".

<!-- KẾT THÚC PROMPT -->

---

## Prompt ngắn (cho từng milestone)
```
Đọc AGENTS.md và docs/plan/. Chạy `harness doctor --json` và `harness get US-00X --json`.
Làm story US-00X theo docs/plan/04-milestones.md, đúng kiến trúc ở docs/plan/02-architecture.md.
Máy là Windows, không có Xcode: push và dùng `gh run watch` để kiểm tra CI; chỉ coi là xong khi CI xanh.
Commit theo từng slice; cập nhật trạng thái chỉ qua `harness story ...`, không sửa tay docs/stories.
Hỏi tôi trước khi tạo repo, tag/release, hoặc đổi thiết kế.
```
