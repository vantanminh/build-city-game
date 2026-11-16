# 00 — Tổng quan dự án

## Tầm nhìn
Game **xây thành phố** (city builder) cho **iOS**, mã nguồn mở trên GitHub. Người chơi tự quy hoạch thành phố của riêng mình: làm đường, khoanh vùng dân cư / thương mại / công nghiệp, xây nhà máy điện, công viên, trường học, bệnh viện. Thành phố tự phát triển theo mô phỏng: dân số, việc làm, nhu cầu, tiền thuế, mức hạnh phúc.

- Tên hiển thị (tạm): **"Thành Phố Của Tôi"**. Codename / target Xcode: `CityBuilder`.
- Phong cách: **isometric 2.5D**, đồ họa **vẽ hoàn toàn bằng code** (không dùng ảnh/asset bên ngoài → không vướng bản quyền).
- Ngôn ngữ UI: tiếng Việt (phase sau có thể thêm tiếng Anh).
- Đây là game **nguyên bản**: không sao chép tên, nhân vật, đồ họa, âm thanh hay giao diện của bất kỳ game thương mại nào.

## Ràng buộc quan trọng
| Ràng buộc | Hệ quả |
|---|---|
| Máy phát triển là **Windows**, không có Mac | Không chạy được Xcode local. **GitHub Actions (macOS runner) là "trình biên dịch" duy nhất cho app iOS.** |
| Open source trên GitHub | Repo public → macOS runner **miễn phí**. Không commit secret. License MIT. |
| Không có (hoặc chưa có) Apple Developer account | CI xuất **IPA unsigned** để sideload (AltStore / SideStore / Sideloadly). Ký số + TestFlight là phase tuỳ chọn. |
| Không có `.xcodeproj` viết tay | Dùng **XcodeGen** (`project.yml`) để sinh project trong CI. `.xcodeproj` nằm trong `.gitignore`. |

## Tech stack
- **Swift 5** (Swift language mode 5, *không* bật strict concurrency của Swift 6 để giảm lỗi biên dịch).
- **SwiftUI** cho HUD / menu / thanh công cụ.
- **SpriteKit** cho bản đồ isometric (render, camera, cử chỉ).
- **Swift Package `CityCore`** (chỉ dùng `Foundation`) chứa toàn bộ logic game & mô phỏng → test được bằng `swift test` trên CI (và trên Windows nếu cài Swift toolchain).
- Không dùng thư viện bên thứ ba (zero dependencies).
- iOS deployment target: **16.0**. Thiết bị: iPhone + iPad.

## Cấu trúc thư mục mục tiêu
```
build-city-game/
├── AGENTS.md                    # hướng dẫn ngắn cho AI agent
├── AGENT_PROMPT.md              # prompt giao việc cho AI agent
├── README.md                    # giới thiệu, ảnh chụp, cách cài IPA
├── LICENSE                      # MIT
├── .gitignore
├── project.yml                  # XcodeGen spec
├── CityCore/                    # Swift Package – logic thuần, không UIKit
│   ├── Package.swift
│   ├── Sources/CityCore/
│   │   ├── TileKind.swift
│   │   ├── Tile.swift
│   │   ├── Tool.swift
│   │   ├── CityMap.swift
│   │   ├── TerrainGenerator.swift
│   │   ├── Simulation.swift
│   │   ├── Economy.swift
│   │   ├── PowerGrid.swift
│   │   ├── CityStats.swift
│   │   ├── GameDate.swift
│   │   ├── SeededRandom.swift
│   │   └── SaveGame.swift
│   └── Tests/CityCoreTests/
│       ├── PlacementTests.swift
│       ├── PowerGridTests.swift
│       ├── SimulationTests.swift
│       └── SaveGameTests.swift
├── CityBuilder/                 # App iOS
│   ├── App/CityBuilderApp.swift
│   ├── Game/GameController.swift      # ObservableObject, cầu nối CityCore ↔ UI
│   ├── Scene/CityScene.swift          # SKScene
│   ├── Scene/IsoMath.swift
│   ├── Scene/TextureFactory.swift     # vẽ texture bằng UIGraphicsImageRenderer
│   ├── Scene/TileNode.swift
│   ├── UI/ContentView.swift
│   ├── UI/TopBarView.swift
│   ├── UI/ToolbarView.swift
│   ├── UI/DemandBarsView.swift
│   ├── UI/TileInfoView.swift
│   ├── UI/SettingsSheet.swift
│   ├── Persistence/SaveStore.swift
│   ├── Resources/Assets.xcassets/AppIcon.appiconset/
│   └── Info.plist (hoặc khai báo trong project.yml)
├── scripts/
│   └── make_icon.swift          # sinh AppIcon 1024x1024 bằng CoreGraphics (chạy trên CI)
├── .github/workflows/
│   ├── ci.yml                   # test CityCore + build app + xuất IPA artifact
│   └── release.yml              # tag v* → GitHub Release kèm IPA
└── docs/plan/                   # các file kế hoạch này
```

## Danh sách tài liệu kế hoạch
1. `00-overview.md` — file này.
2. `01-game-design.md` — luật chơi, số liệu, công thức mô phỏng.
3. `02-architecture.md` — kiến trúc code, model dữ liệu, render isometric, input.
4. `03-ci-cd.md` — XcodeGen, GitHub Actions, IPA unsigned, release, sideload.
5. `04-milestones.md` — các giai đoạn, task, tiêu chí nghiệm thu (checklist).
6. `05-conventions.md` — quy ước code, cách làm việc khi không có Mac.

## Định nghĩa "Xong" cho bản v1.0
- CI xanh trên `main`: `swift test` cho CityCore pass, app build cho iOS Simulator và iphoneos (unsigned) thành công.
- Artifact `CityBuilder-unsigned.ipa` tải được từ mỗi lần chạy CI; tag `v1.0.0` tạo GitHub Release có IPA.
- Chơi được trọn vòng: tạo bản đồ → xây đường, vùng, điện → dân số tăng → thu thuế → lưu/tải game → không crash.
