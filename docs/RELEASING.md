# Phát hành MacKey68

Tài liệu cho maintainer. Không commit chứng chỉ, mật khẩu hay private key.

## 1. Bản không ký (mặc định)

```bash
./scripts/package-dmg.sh
```

Tạo `dist/MacKey68-<version>.dmg` ký ad-hoc. Người dùng phải chuột phải app → **Open**
lần đầu. CI vẫn build được bản này mà không cần secret.

## 2. Ký Developer ID + notarize

Cần tài khoản Apple Developer (99 USD/năm).

### Chuẩn bị chứng chỉ

1. Xcode → Settings → Accounts → **Manage Certificates** → tạo
   **Developer ID Application**.
2. Chuột phải chứng chỉ → **Export** → lưu `.p12` + đặt mật khẩu.
3. Base64 để đưa vào GitHub Secret:

```bash
base64 < DeveloperID.p12 | pbcopy
```

### GitHub Secrets

| Secret | Nội dung |
|---|---|
| `MACKEY_SIGN_IDENTITY` | `Developer ID Application: Tên (TEAMID)` |
| `MACKEY_CERT_P12_BASE64` | file `.p12` đã base64 |
| `MACKEY_CERT_PASSWORD` | mật khẩu `.p12` |
| `APPLE_ID` | Apple ID dùng notarize |
| `TEAM_ID` | Team ID (10 ký tự) |
| `APP_PASSWORD` | app-specific password của Apple ID |
| `SPARKLE_PRIVATE_KEY_BASE64` | private key Sparkle đã base64 |

### Ký local

```bash
MACKEY_SIGN_IDENTITY="Developer ID Application: Tên (TEAMID)" \
  ./scripts/package-dmg.sh

xcrun notarytool store-credentials mackey68-notary \
  --apple-id you@example.com --team-id TEAMID --password "$APP_PASSWORD"

./scripts/notarize.sh dist/MacKey68-<version>.dmg
```

## 3. Sparkle auto-update

- Public key đã nằm trong `scripts/build-app.sh` (`SUPublicEDKey`).
- Private key local: `~/Library/Application Support/MacKey68/sparkle_private_key` (chmod 600). **Sao lưu offline**;
  mất key này thì không thể phát hành update cho các bản đã cài.
- Đưa private key vào secret:

```bash
base64 < "$HOME/Library/Application Support/MacKey68/sparkle_private_key" | pbcopy
```

- Feed URL: `https://github.com/thdat-vu/MacKey68/releases/latest/download/appcast.xml`.
  Workflow tải `appcast.xml` lên release; app lấy asset của release mới nhất.
- Ký appcast thủ công:

```bash
SPARKLE_PRIVATE_KEY_FILE="$HOME/Library/Application Support/MacKey68/sparkle_private_key" \
  ./scripts/make-appcast.sh dist/MacKey68-<version>.dmg
```

Nếu đổi key, phải cập nhật `SUPublicEDKey` trong Info.plist **và** phát hành bản mới;
app cũ sẽ không nhận update nếu key sai.

## 4. CI GitHub Actions

- `.github/workflows/ci.yml`: build + selftest + DMG ad-hoc trên mỗi push/PR.
- `.github/workflows/release.yml`: chạy khi push tag `v*`:
  - build DMG
  - ký nếu có secret
  - notarize nếu có secret
  - ký appcast nếu có Sparkle key
  - tạo/cập nhật GitHub Release, đính kèm DMG + `appcast.xml`

Quy trình release:

```bash
# 1. tăng version + build number trong scripts/build-app.sh
#    CFBundleShortVersionString = 0.5.0, CFBundleVersion = 500
./scripts/package-dmg.sh          # kiểm tra local
./scripts/update-cask.sh          # cập nhật Casks/mackey68.rb

git add -A
git commit -m "Release 0.5.0"
git push
git tag -a v0.7.0 -m "MacKey68 0.7.0"
git push origin v0.7.0
```

Workflow kiểm tra tag khớp `CFBundleShortVersionString` trước khi phát hành.

## 5. Homebrew cask

Cask nằm trong `Casks/mackey68.rb` và cũng nên được copy sang tap
`thdat-vu/homebrew-tap`:

```bash
gh repo create thdat-vu/homebrew-tap --public
mkdir -p /tmp/homebrew-tap/Casks
cp Casks/mackey68.rb /tmp/homebrew-tap/Casks/
cd /tmp/homebrew-tap
git init -b main
git add -A && git commit -m "Add MacKey68 cask"
git remote add origin https://github.com/thdat-vu/homebrew-tap.git
git push -u origin main
```

Người dùng cài:

```bash
brew trust thdat-vu/tap
brew install --cask thdat-vu/tap/mackey68
```

Sau mỗi release, chạy `./scripts/update-cask.sh` rồi copy cask sang tap (hoặc để CI làm
sau này). Bản ad-hoc vẫn bị Gatekeeper cảnh báo lần đầu; muốn hết cảnh báo phải ký
Developer ID + notarize.

## 6. Checklist trước khi tag

- [ ] `swift build -c release`
- [ ] `.build/release/mackey selftest`
- [ ] `./scripts/package-dmg.sh`
- [ ] `./scripts/update-cask.sh`
- [ ] tăng version/build number
- [ ] test mở app, guide, đổi phím, profile, import/export
- [ ] test cắm/rút 2 bàn phím
- [ ] cập nhật README/guide nếu có feature mới
- [ ] tag + push, xem workflow chạy xanh
