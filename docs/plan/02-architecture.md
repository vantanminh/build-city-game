# 02 — Kiến trúc kỹ thuật

## 1. Phân tầng
```
┌───────────────────────── CityBuilder (iOS app) ─────────────────────────┐
│  SwiftUI (ContentView, TopBar, Toolbar, Sheets)                          │
│        ▲ @Published stats              │ user actions (tool, tax, speed) │
│        │                               ▼                                 │
│  GameController (@MainActor, ObservableObject)                           │
│        │ owns                          │ notifies changed tiles          │
│        ▼                               ▼                                 │
│  CityCore.City (model + sim)     CityScene (SKScene) ── TextureFactory   │
└──────────────────────────────────────────────────────────────────────────┘
          CityCore = Swift Package, chỉ import Foundation, có unit test
```
Quy tắc: **CityCore không biết gì về UIKit/SpriteKit/SwiftUI.** Mọi luật chơi nằm trong CityCore để test được bằng `swift test`.

## 2. CityCore — model dữ liệu
```swift
public enum TileKind: UInt8, Codable, CaseIterable {
    case grass, water, forest, road, residential, commercial, industrial,
         park, powerPlant, school, hospital
    public var isZone: Bool { ... }        // R/C/I
    public var conductsPower: Bool { ... } // != grass/water/forest
    public var consumesPower: Bool { ... } // zone, park, school, hospital
}

public struct Tile: Codable, Equatable {
    public var kind: TileKind
    public var level: UInt8      // 0...3
    public var powered: Bool
    public var hasRoadAccess: Bool
    public var variant: UInt8
}

public struct GridPoint: Hashable, Codable { public var x: Int; public var y: Int }

public enum Tool: String, Codable, CaseIterable {
    case inspect, road, residential, commercial, industrial,
         park, powerPlant, school, hospital, bulldoze
    public var cost: Int { ... }
    public var resultingKind: TileKind? { ... }
}

public struct CityMap: Codable {
    public let width: Int, height: Int
    public private(set) var tiles: [Tile]           // index = y * width + x
    public subscript(p: GridPoint) -> Tile { get set }
    public func contains(_ p: GridPoint) -> Bool
    public func neighbors4(_ p: GridPoint) -> [GridPoint]
    public func points(within r: Int, of p: GridPoint) -> some Sequence<GridPoint> // Chebyshev
}

public enum PlacementResult: Equatable {
    case placed(cost: Int), unchanged, notEnoughMoney, blocked(reason: String)
}

public final class City {          // không phải ObservableObject — thuần logic
    public var name: String
    public var map: CityMap
    public var money: Int
    public var taxRate: Int
    public var date: GameDate
    public private(set) var stats: CityStats
    public private(set) var history: [MonthRecord]
    public init(name: String, seed: UInt64, size: Int = 48)
    public func apply(_ tool: Tool, at p: GridPoint) -> PlacementResult
    /// Chạy 1 ngày; trả về danh sách ô đã thay đổi hình ảnh và các sự kiện.
    public func step(rng: inout some RandomNumberGenerator) -> StepResult
    public func snapshot() -> SaveGame
    public init(from save: SaveGame)
}

public struct StepResult { public var changed: [GridPoint]; public var events: [CityEvent] }
public enum CityEvent: Equatable { case monthEnded(income: Int, expenses: Int), milestone(String), bankrupt }
```
- `SaveGame` là `Codable` có trường `version: Int = 1` để migrate sau này. Lưu `seed`, `rngState` để mô phỏng tái lập.
- `SeededRandomNumberGenerator`: SplitMix64, `struct ... : RandomNumberGenerator`, lưu/khôi phục state.
- Các tính toán đắt (power, road access, desirability) dùng **dirty flag**: `apply()` đặt `mapDirty = true`; `step()` tính lại khi dirty.
- Độ phức tạp: 48×48 = 2 304 ô → BFS mỗi lần thay đổi là rẻ; không cần tối ưu thêm.

## 3. App — GameController
```swift
@MainActor final class GameController: ObservableObject {
    @Published private(set) var stats: CityStats
    @Published private(set) var money: Int
    @Published private(set) var dateText: String
    @Published var selectedTool: Tool = .inspect
    @Published var speed: GameSpeed = .normal       // paused/normal/fast/ultra
    @Published var inspected: InspectedTile?
    @Published var toast: String?
    let city: City
    weak var renderer: CityRenderer?                // CityScene conform
    func tap(at p: GridPoint)
    func paint(from: GridPoint?, to: GridPoint)     // kéo để vẽ, nội suy đường thẳng
    func advance(dt: TimeInterval)                  // gọi từ SKScene.update
    func save() / static func loadOrNew()
}
protocol CityRenderer: AnyObject { func refresh(_ points: [GridPoint]); func reloadAll() }
```
- **Không** `@Published` mảng tiles (tránh SwiftUI re-render nặng). Ô thay đổi được đẩy qua `renderer.refresh(_:)`.
- Vòng lặp thời gian: `CityScene.update(_ currentTime:)` tính `dt` → `controller.advance(dt:)` → tích luỹ, mỗi `1/speed` giây gọi `city.step` (tối đa 5 step / frame để không treo).
- Cập nhật `@Published` stats tối đa 1 lần mỗi step (không mỗi frame).

## 4. Render isometric (CityScene)
### 4.1 Toạ độ
```
TW = 64, TH = 32  (điểm)
gridToScene(x, y):  sx = (x - y) * TW/2 ;  sy = -(x + y) * TH/2
sceneToGrid(px, py): a = px / (TW/2) ; b = -py / (TH/2)
                     gx = round((a + b) / 2) ; gy = round((b - a) / 2)
zPosition = CGFloat(x + y)  (công trình cao hơn: + 0.5)
```
- Một `mapNode: SKNode` chứa toàn bộ ô; camera `SKCameraNode` là con của scene.
- Mỗi ô: `groundSprite` (diamond) + `buildingSprite?` (anchorPoint đặt sao cho tâm đáy diamond trùng tâm ô: `anchor = (0.5, (TH/2) / textureHeight)`).
- Icon ⚡ dùng chung texture, `SKAction` nhấp nháy.

### 4.2 TextureFactory
- Vẽ bằng `UIGraphicsImageRenderer` (scale = 2 hoặc `UIScreen.main.scale`) → `SKTexture(image:)`, `filteringMode = .linear`.
- **Cache** theo key (`kind`, `level`, `variant`, `roadMask`). Tạo lazy trên main thread.
- Hàm vẽ cơ bản (toạ độ UIKit, y hướng xuống, tâm đáy `(cx, cy)`):
  - `diamond(cx, cy, hw, hh)` — điểm trên/phải/dưới/trái.
  - `isoBox(cx, cy, halfWidth w, height h, top, left, right)` — 3 mặt: mặt trái = (left, bottom, bottom−h, left−h), mặt phải = (bottom, right, right−h, bottom−h), mặt trên = diamond dịch lên h. Mặt trái tối hơn ~15%, mặt phải tối hơn ~30%.
  - `pyramidRoof(...)` cho nhà dân L1.
  - Vạch tầng: kẻ đường song song cạnh đáy trên mặt bên mỗi 7pt.
- **Đường tự nối**: `roadMask` 4 bit (N=1, E=2, S=4, W=8 theo lưới). Vẽ diamond xám + các dải từ tâm tới trung điểm cạnh tương ứng + vạch giữa. Khi đặt/phá đường, refresh cả 4 ô láng giềng.
- Texture height = `TH + chiều cao công trình + phần mái/ống khói`.

### 4.3 Input (gesture trên `SKView`, thêm trong `didMove(to:)`, chỉ thêm 1 lần)
| Cử chỉ | Hành vi |
|---|---|
| Tap 1 ngón | `controller.tap(at:)` — inspect hoặc áp dụng tool |
| Pan 1 ngón (`maximumNumberOfTouches = 1`) | Nếu tool = `inspect` → di chuyển camera; ngược lại → vẽ liên tục (`paint(from:to:)`) |
| Pan 2 ngón (`minimumNumberOfTouches = 2`) | Luôn di chuyển camera |
| Pinch | Zoom, `camera.scale` kẹp 0.4…2.5 |
- `CityScene` làm `UIGestureRecognizerDelegate`, cho phép pinch + pan 2 ngón nhận đồng thời.
- Chuyển toạ độ: `view → scene` bằng `convertPoint(fromView:)` (đã tính camera) → `mapNode.convert(_:from: self)` → `sceneToGrid`.
- Camera pan: `camera.position.x -= t.x * camera.xScale`, `camera.position.y += t.y * camera.yScale`, kẹp trong bounds bản đồ.
- Ô đang chạm hiện **ô highlight** (diamond viền trắng) + màu đỏ nếu không đặt được.

### 4.4 Tích hợp SwiftUI
```swift
SpriteView(scene: holder.scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
    .ignoresSafeArea()
```
Scene được tạo **một lần** (giữ trong `@StateObject`), `scaleMode = .resizeFill`. HUD là overlay SwiftUI trong `ZStack`.

## 5. Lưu game
- File JSON `Documents/city.json` (`JSONEncoder`, ghi `atomic`).
- Auto-save: cuối mỗi tháng game và khi `scenePhase` chuyển `.background`.
- Lỗi decode (file hỏng/phiên bản lạ) → đổi tên file thành `city.corrupt.json`, bắt đầu game mới, hiện toast.

## 6. Hiệu năng
- 2 304 ô × ≤2 sprite = ~4 600 node: SpriteKit xử lý tốt; bật `ignoresSiblingOrder`.
- Không tạo texture mới mỗi frame; mọi texture qua cache.
- Mục tiêu: 60 fps trên iPhone 11 trở lên.

## 7. Khả năng test
- Unit test (CityCore, `swift test`): đặt/bulldoze & chi phí, road mask, power BFS + capacity, demand công thức, phát triển với RNG seed cố định, chốt sổ tháng, encode/decode SaveGame round-trip, sinh địa hình tất định theo seed.
- App target: không có UI test ở v1 (CI chỉ build). Có thể thêm XCUITest smoke test ở phase sau.
