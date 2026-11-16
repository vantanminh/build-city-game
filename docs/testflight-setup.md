# Hướng dẫn đưa Thành Phố Của Tôi lên TestFlight (từ Windows)

Workflow [`.github/workflows/testflight.yml`](../.github/workflows/testflight.yml) tự động test `CityCore`, ký số bản `Release` và đẩy `.ipa` lên **TestFlight** trên GitHub Actions (`macos-15`). Toàn bộ khâu chuẩn bị chứng chỉ bên dưới thực hiện được trực tiếp trên **Windows** (không cần máy Mac).

> **Lưu ý bảo mật:** Tạo và lưu các file khoá (`.key`, `.cer`, `.p12`, `.mobileprovision`, `.p8`) trong một thư mục riêng **ngoài repo** (ví dụ `D:\apple-signing\`), tuyệt đối không commit vào Git.

---

## Bước 1 — Tạo App ID & App trên Apple Developer / App Store Connect

1. Đăng nhập **Apple Developer** → **Certificates, Identifiers & Profiles** → **Identifiers** → nhấn **`+`**:
   - Chọn **App IDs** → **App**.
   - **Description:** `CityBuilder`
   - **Bundle ID (Explicit):** `io.github.vantanminh.citybuilder` *(khớp với `project.yml`)*.
   - Nhấn **Continue** → **Register**.
2. Đăng nhập **App Store Connect** → **Apps** → nhấn **`+` (New App)**:
   - **Platforms:** iOS
   - **Name:** `Thành Phố Của Tôi` *(hoặc tên chưa trùng trên App Store)*
   - **Primary Language:** Vietnamese
   - **Bundle ID:** chọn `io.github.vantanminh.citybuilder`
   - **SKU:** ví dụ `citybuilder-v1`
   - Nhấn **Create**.

---

## Bước 2 — Tạo chứng chỉ Apple Distribution (`.p12`) ngay trên Windows

Mở **PowerShell** tại thư mục riêng ngoài repo (ví dụ `mkdir $HOME\apple-signing; cd $HOME\apple-signing`):

1. **Tạo Private Key và CSR** (thay email Apple ID của bạn vào câu lệnh):
   ```powershell
   $openssl = "C:\Program Files\Git\mingw64\bin\openssl.exe"
   & $openssl genrsa -out dist.key 2048
   & $openssl req -new -key dist.key -out dist.csr -subj "/emailAddress=YOUR_APPLE_EMAIL/CN=CityBuilder Distribution/C=VN"
   ```
2. **Tạo Apple Distribution Certificate trên web:**
   - Vào **Apple Developer** → **Certificates** → **`+`** → chọn **Apple Distribution**.
   - Tải lên file `dist.csr` vừa tạo → tải về file `distribution.cer` (lưu vào cùng thư mục `$HOME\apple-signing`).
3. **Đóng gói thành `.p12` tương thích macOS:**
   ```powershell
   & $openssl x509 -in distribution.cer -inform DER -out dist.pem -outform PEM
   & $openssl pkcs12 -export -legacy -inkey dist.key -in dist.pem -out distribution.p12
   ```
   *(Nhập một mật khẩu bảo vệ file `.p12` — giữ lại mật khẩu này cho Secret `P12_PASSWORD`.)*

---

## Bước 3 — Tạo App Store Provisioning Profile

1. Vào **Apple Developer** → **Profiles** → nhấn **`+`**.
2. Chọn mục **Distribution** → **App Store Connect** → **Continue**.
3. Chọn **App ID** `io.github.vantanminh.citybuilder` → **Continue**.
4. Chọn **Apple Distribution Certificate** vừa tạo ở Bước 2 → **Continue**.
5. Đặt tên Profile (ví dụ `CityBuilder AppStore`) → **Generate** → tải về file `.mobileprovision`.

---

## Bước 4 — Tạo App Store Connect API Key (`.p8`)

1. Vào **App Store Connect** → **Users and Access** → tab **Integrations** → **App Store Connect API**.
2. Nhấn **`+` (Generate API Key)**:
   - **Name:** `GitHub Actions TestFlight`
   - **Access:** **App Manager** (hoặc **Admin**)
3. Tải về file `AuthKey_<KEY_ID>.p8` *(chỉ tải được 1 lần)* và ghi lại:
   - **Issuer ID** (ở đầu trang)
   - **Key ID** (bên cạnh tên key vừa tạo)

---

## Bước 5 — Nạp 6 GitHub Secrets cho repo

Chạy trong **PowerShell** tại thư mục repo `e:\build-city-game` (cần đã đăng nhập `gh auth login`, thay đúng đường dẫn file của bạn):

```powershell
$dir = "$HOME\apple-signing"
$certB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("$dir\distribution.p12"))
$profB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Get-ChildItem "$dir\*.mobileprovision" | Select-Object -First 1).FullName))
$keyB64  = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Get-ChildItem "$dir\AuthKey_*.p8" | Select-Object -First 1).FullName))

gh secret set BUILD_CERTIFICATE_BASE64 --body $certB64
gh secret set PROVISION_PROFILE_BASE64 --body $profB64
gh secret set APP_STORE_CONNECT_API_KEY_BASE64 --body $keyB64
gh secret set P12_PASSWORD                      # nhập mật khẩu .p12 khi được hỏi
gh secret set APP_STORE_CONNECT_API_KEY_ID      # nhập Key ID (10 ký tự)
gh secret set APP_STORE_CONNECT_API_ISSUER_ID   # nhập Issuer ID (UUID)
```

*(Hoặc nạp thủ công trên GitHub: **Settings → Secrets and variables → Actions → New repository secret**.)*

---

## Bước 6 — Chạy workflow đưa build lên TestFlight

- Trên GitHub: vào tab **Actions → TestFlight → Run workflow** (chọn nhánh `main`), hoặc chạy bằng CLI:
  ```powershell
  gh workflow run testflight.yml
  gh run watch
  ```
- Sau khi workflow xanh, chờ 5–15 phút để Apple xử lý bản build, rồi vào **App Store Connect → TestFlight** thêm tester nội bộ/bên ngoài để cài qua app TestFlight trên iPhone/iPad.
- Mỗi lần upload bản mới cùng version `1.0.0`, `build_number` mặc định tự tăng theo `github.run_number` (hoặc nhập tay khi chạy `Run workflow`).
