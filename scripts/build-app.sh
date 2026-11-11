#!/usr/bin/env bash
# Đóng gói binary SwiftUI thành một .app thật (không cần Xcode).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product MacKey68

# Icon được vẽ bằng scripts/make-icon.swift (chỉ tạo lại khi chưa có).
if [[ ! -f Assets/AppIcon.icns ]]; then
    ./scripts/make-icon.sh
fi

APP="build/MacKey68.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MacKey68 "$APP/Contents/MacOS/MacKey68"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>MacKey68</string>
    <key>CFBundleDisplayName</key>     <string>MacKey68</string>
    <key>CFBundleIdentifier</key>      <string>com.mackey68.app</string>
    <key>CFBundleExecutable</key>      <string>MacKey68</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundleShortVersionString</key> <string>0.3.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>    <string>com.mackey68.app</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>mackey68</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Ký: mặc định ad-hoc (chạy được trên máy này). Bản phát hành cho người khác nên
# đặt MACKEY_SIGN_IDENTITY="Developer ID Application: ..." để Gatekeeper chấp nhận.
if [[ -n "${MACKEY_SIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp \
        --sign "$MACKEY_SIGN_IDENTITY" "$APP" \
        || echo "cảnh báo: codesign bằng Developer ID thất bại"
else
    codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "cảnh báo: codesign ad-hoc thất bại"
fi

echo "→ $APP"
