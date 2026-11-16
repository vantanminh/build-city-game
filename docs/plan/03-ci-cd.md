# 03 — CI/CD với GitHub Actions

## 1. Nguyên tắc
- Máy dev là Windows → **mọi bước biên dịch Swift cho iOS chạy trên `macos` runner** của GitHub.
- Repo public → phút macOS miễn phí. Vẫn nên dùng `concurrency` để huỷ run cũ.
- Không commit `CityBuilder.xcodeproj` — sinh bằng **XcodeGen** trong CI.
- Không hard-code tên simulator (thay đổi theo phiên bản Xcode); build dùng `generic/platform=iOS Simulator`.
- In `xcodebuild -version` và `swift --version` ở đầu job để dễ debug.

## 2. `project.yml` (XcodeGen) — mẫu
```yaml
name: CityBuilder
options:
  bundleIdPrefix: io.github.CHANGE_ME          # đổi thành username GitHub
  deploymentTarget:
    iOS: "16.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.0"
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: "1"
packages:
  CityCore:
    path: CityCore
targets:
  CityBuilder:
    type: application
    platform: iOS
    sources:
      - path: CityBuilder
    dependencies:
      - package: CityCore
    info:
      path: CityBuilder/Info.plist
      properties:
        CFBundleDisplayName: "Thành Phố Của Tôi"
        UILaunchScreen: {}
        UIRequiresFullScreen: false
        UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait, UIInterfaceOrientationLandscapeLeft, UIInterfaceOrientationLandscapeRight]
        UISupportedInterfaceOrientations~ipad: [UIInterfaceOrientationPortrait, UIInterfaceOrientationPortraitUpsideDown, UIInterfaceOrientationLandscapeLeft, UIInterfaceOrientationLandscapeRight]
        ITSAppUsesNonExemptEncryption: false
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: io.github.CHANGE_ME.citybuilder
        TARGETED_DEVICE_FAMILY: "1,2"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        GENERATE_INFOPLIST_FILE: NO
    scheme:
      testTargets: []
```
> Agent phải kiểm tra cú pháp XcodeGen theo tài liệu chính thức (https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md) nếu CI báo lỗi.

## 3. `.github/workflows/ci.yml` — mẫu
```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  core-tests:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - run: swift --version
      - name: Test CityCore
        working-directory: CityCore
        run: swift test

  build-ios:
    runs-on: macos-15
    needs: core-tests
    steps:
      - uses: actions/checkout@v4
      - run: xcodebuild -version
      - name: Install XcodeGen
        run: brew install xcodegen
      - name: Generate app icon
        run: swift scripts/make_icon.swift CityBuilder/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
      - name: Generate Xcode project
        run: xcodegen generate
      - name: Build for Simulator
        run: |
          set -o pipefail
          xcodebuild -project CityBuilder.xcodeproj -scheme CityBuilder \
            -configuration Debug -destination 'generic/platform=iOS Simulator' \
            -derivedDataPath build/sim CODE_SIGNING_ALLOWED=NO build | tee build-sim.log
      - name: Build unsigned device app
        run: |
          set -o pipefail
          xcodebuild -project CityBuilder.xcodeproj -scheme CityBuilder \
            -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
            -derivedDataPath build/device \
            CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
            build | tee build-device.log
      - name: Package unsigned IPA
        run: |
          mkdir -p Payload
          cp -R build/device/Build/Products/Release-iphoneos/CityBuilder.app Payload/
          zip -qry CityBuilder-unsigned.ipa Payload
      - name: Zip simulator app
        run: |
          cd build/sim/Build/Products/Debug-iphonesimulator
          zip -qry "$GITHUB_WORKSPACE/CityBuilder-simulator.zip" CityBuilder.app
      - uses: actions/upload-artifact@v4
        with:
          name: CityBuilder-${{ github.sha }}
          path: |
            CityBuilder-unsigned.ipa
            CityBuilder-simulator.zip
          retention-days: 14
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: build-logs
          path: "*.log"
```
Gợi ý: có thể thêm `xcpretty` hoặc `xcbeautify` (`brew install xcbeautify`) để log dễ đọc; khi lỗi, tìm dòng `error:` trong log.

## 4. `.github/workflows/release.yml`
- Trigger: `push` tag `v*`.
- Các bước giống `build-ios` (có thể tách thành reusable workflow `workflow_call` để không lặp), đặt `MARKETING_VERSION` = tag (bỏ chữ `v`) và `CURRENT_PROJECT_VERSION` = `github.run_number`.
- Đăng release bằng `softprops/action-gh-release@v2` kèm `CityBuilder-unsigned.ipa`; `permissions: contents: write`.

## 5. Icon app không cần ảnh có sẵn
`scripts/make_icon.swift` (chạy bằng `swift` trên macOS runner, import `AppKit`/`CoreGraphics`):
- Vẽ nền gradient trời xanh, 3–5 khối nhà isometric màu sắc, xuất PNG 1024×1024 **không có kênh alpha** (App Store yêu cầu không trong suốt).
- `AppIcon.appiconset/Contents.json` dạng single-size:
```json
{ "images": [ { "filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024" } ],
  "info": { "author": "xcode", "version": 1 } }
```
- File PNG sinh ra nằm trong `.gitignore` *hoặc* được commit — chọn một và ghi rõ trong README. (Khuyến nghị: không commit, sinh trong CI.)

## 6. Cài IPA lên iPhone (ghi vào README)
IPA unsigned **không** cài trực tiếp được. Các cách:
1. **AltStore / SideStore** (miễn phí, Apple ID thường, ký lại mỗi 7 ngày).
2. **Sideloadly** (Windows/macOS) — kéo thả IPA, đăng nhập Apple ID.
3. Có tài khoản Apple Developer ($99/năm) → dùng phase ký số bên dưới, phát hành qua TestFlight.

Bản simulator (`CityBuilder-simulator.zip`) chỉ chạy trên máy Mac có Xcode: `xcrun simctl install booted CityBuilder.app`.

## 7. (Tuỳ chọn, phase sau) Ký số + TestFlight
Secrets cần: `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `PROVISION_PROFILE_BASE64`, `KEYCHAIN_PASSWORD`, `APP_STORE_CONNECT_API_KEY_ID`, `..._ISSUER_ID`, `..._KEY_BASE64`.
Luồng: tạo keychain tạm → import p12 → cài profile → `xcodebuild archive` → `xcodebuild -exportArchive` với `ExportOptions.plist` → `xcrun altool --upload-app` hoặc `fastlane pilot`. Workflow này chỉ chạy khi secrets tồn tại (`if: env.BUILD_CERTIFICATE_BASE64 != ''`), để fork của người khác không bị lỗi.

## 8. Kiểm tra trạng thái CI từ Windows
```powershell
gh run list --limit 5
gh run watch                     # theo dõi run mới nhất
gh run view <run-id> --log-failed
gh run download <run-id> -n CityBuilder-<sha>
```
