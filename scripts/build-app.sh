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
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp .build/release/MacKey68 "$APP/Contents/MacOS/MacKey68"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Sparkle.framework is a SwiftPM binary artifact; copy it into the bundle and
# teach the executable where to find it.
SPARKLE_FW="$(find .build -maxdepth 4 -name Sparkle.framework -type d | head -1)"
if [[ -n "$SPARKLE_FW" ]]; then
    cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/"
    install_name_tool -add_rpath "@executable_path/../Frameworks" \
        "$APP/Contents/MacOS/MacKey68" 2>/dev/null || true
fi

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
    <key>CFBundleShortVersionString</key> <string>0.12.0</string>
    <key>CFBundleVersion</key>         <string>1200</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Vu Thanh Dat. Independent project; not affiliated with keyboard vendors. GPL-3.0-or-later.</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSInputMonitoringUsageDescription</key>
    <string>MacKey68 reads key presses only when you open Keyboard Lab or run `mackey watch`.</string>
    <key>SUFeedURL</key>
    <string>https://github.com/thdat-vu/MacKey68/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>bRGxLeunSi6BlW8Dx8OgMzGxotvoPeEwhsrjtlOchOY=</string>
    <key>SUEnableAutomaticChecks</key> <true/>
    <key>SUScheduledCheckInterval</key> <integer>86400</integer>
    <key>SUAllowsAutomaticUpdates</key> <true/>
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
