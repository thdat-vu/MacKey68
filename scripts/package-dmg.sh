#!/usr/bin/env bash
# Đóng gói MacKey68.app thành DMG kéo-vào-Applications để phát hành.
#   ./scripts/package-dmg.sh
#   MACKEY_SIGN_IDENTITY="Developer ID Application: Ten (TEAMID)" ./scripts/package-dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh

APP="build/MacKey68.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DIST="dist"
DMG="$DIST/MacKey68-$VERSION.dmg"
mkdir -p "$DIST"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ROOT="$STAGE/MacKey68"
mkdir -p "$ROOT"
cp -R "$APP" "$ROOT/"
ln -s /Applications "$ROOT/Applications"

cat > "$ROOT/Read me.txt" <<'TXT'
MacKey68 — Ziyoulang K68 as a macOS keyboard

1. Kéo MacKey68 vào thư mục Applications.
2. Mở MacKey68. Lần đầu macOS có thể cảnh báo vì app chưa notarize:
   chuột phải vào app → Open → Open.
3. App nằm ở menu bar (icon bàn phím). Bấm icon → Open keyboard… để
   mở bàn phím vẽ ra và đổi phím.
4. App tự đăng ký chạy khi đăng nhập. Tắt trong menu bar nếu không muốn.

Gỡ: xoá app khỏi Applications, rồi xoá
~/Library/LaunchAgents/com.mackey68.app.plist và thư mục ~/.config/mackey.
TXT

rm -f "$DMG"
hdiutil create \
    -volname "MacKey68 $VERSION" \
    -srcfolder "$ROOT" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG" >/dev/null

echo "→ $DMG"
shasum -a 256 "$DMG"
echo
echo "Người dùng tải về: mở DMG, kéo MacKey68 vào Applications, mở app."
echo "Nếu macOS chặn: chuột phải app → Open (hoặc bật Privacy & Security → Open Anyway)."
