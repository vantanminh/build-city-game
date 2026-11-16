# 04 — Lộ trình & checklist

> **Trạng thái chính thức nằm trong harness**, không nằm ở file này. Mỗi milestone = 1 story:
>
> | Milestone | Story | Lane |
> |---|---|---|
> | M0 | `US-001` | normal |
> | M1 | `US-002` | normal |
> | M2 | `US-003` | normal |
> | M3 | `US-004` | normal |
> | M4 | `US-005` | high-risk |
> | M5 | `US-006` | normal |
> | M6 | `US-007` | normal |
> | M7 | `US-008` | normal |
>
> Bắt đầu: `harness story start US-00X` · Xong: `harness story done US-00X` (chỉ khi **CI xanh**).
> Checklist bên dưới là danh sách việc chi tiết; agent có thể tick `[x]` để theo dõi, nhưng không thay cho lệnh harness.
> Intake gốc: `IN-001`. Quyết định kiến trúc: `DEC-001` … `DEC-005` (`harness query decisions --json`).

## M0 — Khởi tạo repo & CI "Hello"
- [ ] `git init`, `.gitignore` (Xcode, SwiftPM `.build/`, `*.xcodeproj`, `build/`, `Payload/`, `*.ipa`, icon PNG sinh tự động, `.DS_Store`)
- [ ] `LICENSE` (MIT), `README.md` khung
- [ ] `project.yml` + app SwiftUI tối thiểu hiển thị "Thành Phố Của Tôi"
- [ ] `CityCore` package rỗng + 1 test giả
- [ ] `scripts/make_icon.swift` + `AppIcon.appiconset/Contents.json`
- [ ] `.github/workflows/ci.yml`
- [ ] Tạo repo GitHub (**hỏi người dùng tên repo & xác nhận public trước khi tạo/push**), push, CI xanh, tải được IPA artifact

**Nghiệm thu:** `gh run list` hiện run thành công, artifact chứa `CityBuilder-unsigned.ipa`.

## M1 — CityCore: model & đặt công trình
- [ ] `TileKind`, `Tile`, `GridPoint`, `Tool`, `Balance` (hằng số)
- [ ] `CityMap` + `neighbors4`, `points(within:)`
- [ ] `SeededRandomNumberGenerator` (SplitMix64)
- [ ] `TerrainGenerator` tất định theo seed (hồ/sông, rừng, vùng trung tâm trống)
- [ ] `City.apply(_:at:)` với đầy đủ luật ở `01-game-design.md §3`
- [ ] `roadMask(at:)`
- [ ] Test: chi phí, chặn trên nước, phá rừng, không đủ tiền, bulldoze, terrain cùng seed → cùng map

## M2 — Bản đồ isometric hiển thị được
- [ ] `IsoMath` (+ test chuyển đổi 2 chiều nếu đặt trong CityCore)
- [ ] `TextureFactory`: grass, water, forest, road (16 mask), zone L0
- [ ] `CityScene` vẽ toàn bộ bản đồ, camera pan (1 & 2 ngón) + pinch zoom, kẹp bounds
- [ ] Highlight ô dưới ngón tay

**Nghiệm thu:** CI build xanh; (nếu người dùng cài được IPA) thấy bản đồ, kéo/zoom mượt.

## M3 — Xây dựng tương tác
- [ ] `GameController` + `CityRenderer`
- [ ] Toolbar SwiftUI, chọn tool, tap để đặt, kéo để vẽ (nội suy, không bị đứt nét)
- [ ] Texture công trình: R/C/I L1–L3, park, powerPlant, school, hospital
- [ ] Toast + haptic khi không đủ tiền / bị chặn
- [ ] Hiệu ứng "pop" khi đặt

## M4 — Mô phỏng
- [ ] Road access, PowerGrid (BFS + capacity), desirability (cache dirty)
- [ ] CityStats, demand RCI, phát triển/suy thoái, happiness
- [ ] GameDate + tốc độ (pause/1×/3×/10×), vòng lặp trong `SKScene.update`
- [ ] Icon ⚡ cho ô thiếu điện
- [ ] Test: power capacity cắt đúng số ô; vùng không đường không lên level; seed cố định → kết quả 365 tick tất định; demand đúng công thức

## M5 — Kinh tế & HUD
- [ ] Chốt sổ tháng, lịch sử 24 tháng, phá sản
- [ ] TopBar (tiền, dân số, ngày, hạnh phúc, tốc độ), DemandBars
- [ ] TileInfo khi inspect
- [ ] Settings sheet: slider thuế, biểu đồ thu/chi (SwiftUI `Path` hoặc Swift Charts – iOS 16 có Charts), Giới thiệu
- [ ] Cột mốc dân số + cảnh báo
- [ ] Test: income/expenses đúng công thức, phá sản sau 3 tháng

## M6 — Lưu/tải & màn hình bắt đầu
- [ ] `SaveGame` (version 1) + round-trip test
- [ ] `SaveStore` (atomic write, xử lý file hỏng)
- [ ] Auto-save cuối tháng & khi vào background
- [ ] Màn hình bắt đầu: Tiếp tục / Thành phố mới (tên + seed)

## M7 — Hoàn thiện & phát hành v1.0.0
- [ ] `release.yml` (tag → Release + IPA)
- [ ] README đầy đủ: mô tả, ảnh chụp (nếu có), tính năng, cách build qua CI, cách cài IPA (AltStore/SideStore/Sideloadly), đóng góp, license
- [ ] `CONTRIBUTING.md`, issue templates (bug/feature) — tuỳ chọn
- [ ] Rà soát: không có warning nghiêm trọng, không force-unwrap nguy hiểm, không crash khi bản đồ trống
- [ ] Tag `v1.0.0` (**hỏi người dùng trước khi tạo tag/release**)

## Backlog (sau v1)
- [ ] Ký số + TestFlight (`03-ci-cd.md §7`)
- [ ] Tiếng Anh (String Catalog `Localizable.xcstrings`)
- [ ] Công trình 2×2 (sân vận động, sân bay), xe chạy trên đường
- [ ] Ô nhiễm, cảnh sát, cứu hoả, nước sạch
- [ ] Ngày/đêm, âm thanh CC0
- [ ] XCUITest smoke test chạy trên simulator trong CI
