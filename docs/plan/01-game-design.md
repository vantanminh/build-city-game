# 01 — Thiết kế game (Game Design)

> Mọi con số dưới đây là **giá trị khởi điểm**, đặt trong một file hằng số duy nhất (`Balance.swift` trong CityCore) để dễ cân bằng lại.

## 1. Bản đồ
- Lưới vuông **48 × 48** ô, hiển thị isometric.
- Địa hình sinh ngẫu nhiên theo **seed** (để tái lập & test được):
  - 1–3 hồ nước (blob ngẫu nhiên) hoặc 1 con sông chạy ngang/dọc.
  - Các cụm rừng (forest) rải rác, chiếm ~12–18% diện tích.
  - Phần còn lại là cỏ (grass).
  - Vùng trung tâm bán kính 6 ô luôn là cỏ để người chơi có chỗ bắt đầu.

## 2. Loại ô (TileKind)
| Kind | Mô tả | Có thể xây lên? |
|---|---|---|
| `grass` | Đất trống | Có |
| `water` | Nước | Không (v1) |
| `forest` | Rừng | Có, tự phá rừng (+chi phí phá) |
| `road` | Đường | — |
| `residential` | Vùng dân cư (R) | — |
| `commercial` | Vùng thương mại (C) | — |
| `industrial` | Vùng công nghiệp (I) | — |
| `park` | Công viên | — |
| `powerPlant` | Nhà máy điện | — |
| `school` | Trường học | — |
| `hospital` | Bệnh viện | — |

Mỗi `Tile` có: `kind`, `level: Int` (0…3, chỉ dùng cho vùng R/C/I; 0 = đất đã khoanh vùng nhưng chưa có nhà), `powered: Bool`, `hasRoadAccess: Bool`, `variant: UInt8` (biến thể hình ảnh ngẫu nhiên, cố định theo seed).

Tất cả công trình đều **1×1 ô** ở v1 (đơn giản hoá; công trình nhiều ô để phase sau).

## 3. Công cụ (Tool) & chi phí
| Tool | Chi phí ($) | Ghi chú |
|---|---|---|
| `inspect` | 0 | Chạm để xem thông tin ô. Kéo 1 ngón = di chuyển camera. |
| `road` | 10 | Kéo để vẽ đường liên tục. Đường tự nối hình (16 biến thể theo 4 hướng). |
| `residential` | 20 | Khoanh vùng R, kéo để tô nhiều ô. |
| `commercial` | 20 | Khoanh vùng C. |
| `industrial` | 20 | Khoanh vùng I. |
| `park` | 100 | |
| `powerPlant` | 3000 | Cung cấp điện cho **80** ô tiêu thụ. |
| `school` | 1500 | |
| `hospital` | 2000 | |
| `bulldoze` | 5 | Phá công trình → về `grass`. Phá rừng: 10. Không phá được nước. |

Luật đặt:
- Không đặt lên `water`.
- Đặt lên `forest` → cộng thêm phí phá rừng 10.
- Đặt lên ô đã có công trình khác → **không cho phép** (phải bulldoze trước). Đặt cùng loại → bỏ qua, không tốn tiền.
- Không đủ tiền → từ chối, UI rung nhẹ (haptic) + toast "Không đủ tiền".

## 4. Thời gian
- 1 tick = 1 ngày trong game. Tốc độ: **Tạm dừng / 1× (1 tick/giây) / 3× / 10×**.
- 1 tháng = 30 ngày, 1 năm = 12 tháng. Bắt đầu: Năm 1, Tháng 1.
- Hiển thị: "Th 3 · Năm 2".

## 5. Mô phỏng (mỗi tick)
Thứ tự xử lý trong `Simulation.step()`:

### 5.1 Truy cập đường (road access)
Ô vùng/công trình có `hasRoadAccess = true` nếu có ô `road` trong phạm vi **Chebyshev ≤ 2**. Chỉ tính lại khi bản đồ thay đổi (dirty flag), không cần mỗi tick.

### 5.2 Lưới điện (PowerGrid)
- Ô **dẫn điện**: mọi ô không phải `grass`, `water`, `forest` (tức đường, vùng, công trình đều dẫn).
- BFS 4 hướng tạo các **thành phần liên thông**. Trong mỗi thành phần:
  - `capacity = số nhà máy điện × 80`
  - Ô **tiêu thụ** = vùng R/C/I + park + school + hospital (đường và nhà máy không tiêu thụ).
  - Duyệt ô tiêu thụ theo thứ tự BFS; `capacity` ô đầu tiên được `powered = true`, còn lại `false`.
- Chỉ tính lại khi bản đồ thay đổi hoặc mỗi 10 tick.

### 5.3 Chỉ số thành phố (CityStats)
```
population  = Σ (level của ô R) × 25
comJobs     = Σ (level của ô C) × 15
indJobs     = Σ (level của ô I) × 20
jobs        = comJobs + indJobs
```

### 5.4 Nhu cầu RCI (trong khoảng −1 … +1)
```
resDemand = clamp((jobs × 1.1 + 60 − population) / 120, −1, 1)
comDemand = clamp((population × 0.35 − comJobs) / 60,  −1, 1)
indDemand = clamp((population × 0.45 − indJobs) / 60,  −1, 1)
```
Thuế cao làm giảm nhu cầu: mỗi demand trừ thêm `(taxRate − 9) × 0.03`.

### 5.5 Giá trị đất / mức hấp dẫn (desirability) của từng ô, thang 0…100
Khởi điểm 50, rồi:
- `park` trong bán kính 4: +8 mỗi cái (tối đa +24)
- `school` trong bán kính 8: +10 (không cộng dồn)
- `hospital` trong bán kính 8: +10 (không cộng dồn)
- `water` trong bán kính 2: +6
- `forest` trong bán kính 2: +3
- `industrial` trong bán kính 4: −6 mỗi cái (tối đa −30) — **chỉ áp dụng cho ô R**
- `powerPlant` trong bán kính 5: −15 — chỉ áp dụng cho ô R
Tính lại khi bản đồ thay đổi (cache theo dirty flag).

### 5.6 Phát triển / suy thoái
Mỗi tick chọn ngẫu nhiên **~10% số ô vùng** (tối thiểu 1) để xét:
- **Điều kiện tăng level**: `powered && hasRoadAccess && demand(loại) > 0 && level < maxLevel(ô)`
  - `maxLevel` của ô R: 1 nếu desirability < 40, 2 nếu < 65, 3 nếu ≥ 65. Ô C/I luôn 3.
  - Xác suất tăng: `0.25 × demand × happinessFactor` với `happinessFactor = 0.5 + happiness/100`.
- **Điều kiện giảm level** (nếu `level > 0`): `!powered || !hasRoadAccess || demand < −0.4` → xác suất 0.15 giảm 1 level.

Dùng `SeededRandomNumberGenerator` (SplitMix64) truyền vào để test được tất định.

### 5.7 Hạnh phúc (happiness, 0…100)
```
base           = 50
+ 15 nếu tỉ lệ ô R có điện ≥ 95%
+ trung bình desirability của ô R − 50   (kẹp −20…+20)
+ 10 nếu có ≥ 1 school,  + 10 nếu có ≥ 1 hospital (khi population > 200)
− (taxRate − 9) × 3
− 10 nếu thất nghiệp: population × 0.6 > jobs
```
Kẹp 0…100. Làm mượt: `happiness = happiness × 0.9 + target × 0.1` mỗi tick.

## 6. Kinh tế (chốt sổ cuối mỗi tháng)
- Tiền khởi điểm: **$20 000**. Thuế mặc định **9%**, chỉnh được 0–20%.
```
income   = population × taxRate% × 1.6 + jobs × taxRate% × 1.2
expenses = roads × 1 + powerPlants × 60 + schools × 40 + hospitals × 50 + parks × 3
money   += income − expenses   (làm tròn về Int)
```
- Lưu lịch sử 24 tháng gần nhất (income, expenses, population) để vẽ biểu đồ đơn giản.
- Tiền âm được phép tới **−$5 000**; nếu dưới mức này 3 tháng liên tiếp → thông báo "Thành phố phá sản" với lựa chọn chơi lại.

## 7. Cột mốc & thông báo (nhẹ, tạo động lực)
Toast khi đạt dân số 100 / 500 / 1 000 / 5 000 / 10 000 ("Làng → Thị trấn → Thị xã → Thành phố → Đô thị lớn"). Cảnh báo khi: nhiều ô thiếu điện, thiếu đường, tiền âm.

## 8. Giao diện (UI)
- **Thanh trên (TopBar)**: tiền, dân số, ngày tháng, mặt cười hạnh phúc, nút tốc độ, nút menu (⚙︎).
- **Thanh nhu cầu RCI**: 3 cột nhỏ xanh lá / xanh dương / vàng, dương lên trên, âm xuống dưới.
- **Thanh công cụ dưới (Toolbar)**: cuộn ngang, nút có SF Symbol + giá. Công cụ đang chọn được highlight.
  - Gợi ý SF Symbols: inspect `hand.point.up`, road `road.lanes`, R `house.fill`, C `cart.fill`, I `building.2.fill`, park `tree.fill`, power `bolt.fill`, school `graduationcap.fill`, hospital `cross.case.fill`, bulldoze `hammer.fill`.
- **Thông tin ô (TileInfo)**: sheet/card khi chạm bằng `inspect`: loại, level, điện, đường, desirability.
- **Menu cài đặt**: thuế (slider), biểu đồ tài chính, Lưu, Tạo bản đồ mới (xác nhận), Giới thiệu/License.
- Màn hình khởi động: "Tiếp tục" (nếu có save) / "Thành phố mới" (nhập tên thành phố, seed tuỳ chọn).

## 9. Đồ hoạ (vẽ bằng code)
- Ô isometric 64×32 điểm. Màu bảng gợi ý:
  - grass `#7BC67B`, water `#4FA3E0`, forest nền `#5DAE5D` + cây tròn `#2E7D32`
  - road `#5A5A5A` vạch giữa `#E0E0E0`
  - R: mái đỏ/cam, tường kem; C: xanh dương/kính; I: vàng nâu + ống khói xám
  - park: cỏ đậm + lối đi be + 2–3 cây; power: khối xám + 2 ống khói; school: tường cam + cờ; hospital: trắng + chữ thập đỏ
  - Ô vùng level 0: nền màu vùng nhạt (R xanh lá nhạt, C xanh dương nhạt, I vàng nhạt) + viền.
- Chiều cao nhà theo level: L1 ≈ 14pt, L2 ≈ 28pt, L3 ≈ 52pt; có vạch tầng trên mặt bên.
- Ô không có điện (vùng/công trình tiêu thụ): icon ⚡ nhỏ nhấp nháy phía trên.
- Hiệu ứng nhỏ: khi đặt công trình scale 0.8→1.0 trong 0.15s; khói bay từ ống khói nhà máy (SKEmitterNode tạo bằng code, tuỳ chọn).

## 10. Âm thanh / haptic
- v1: chỉ haptic (`UIImpactFeedbackGenerator` khi đặt, `UINotificationFeedbackGenerator.error` khi không đủ tiền).
- Âm thanh: phase sau, chỉ dùng âm thanh tự tổng hợp hoặc license CC0.

## 11. Ngoài phạm vi v1 (backlog)
Công trình nhiều ô, giao thông/xe chạy, ô nhiễm, tội phạm/cảnh sát, cứu hoả, thảm hoạ, nước sạch, Game Center, iCloud sync, đa ngôn ngữ, chế độ ngày/đêm.
