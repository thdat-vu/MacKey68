#!/usr/bin/env bash
# Cài app vào ~/Applications và cho nó tự chạy khi đăng nhập.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh

DEST="$HOME/Applications/MacKey68.app"
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R build/MacKey68.app "$DEST"

# Đăng ký lại với LaunchServices để icon và URL scheme mackey68:// có hiệu lực ngay.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -f "$DEST" >/dev/null 2>&1 || true

PLIST="$HOME/Library/LaunchAgents/com.mackey68.app.plist"
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>            <string>com.mackey68.app</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>-a</string>
        <string>$DEST</string>
        <string>--args</string>
        <string>--agent</string>
    </array>
    <key>RunAtLoad</key>        <true/>
    <key>KeepAlive</key>        <false/>
    <key>ProcessType</key>      <string>Interactive</string>
    <key>StandardOutPath</key>  <string>$HOME/Library/Logs/MacKey68.log</string>
    <key>StandardErrorPath</key><string>$HOME/Library/Logs/MacKey68.log</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/com.mackey68.app"

echo "→ $DEST"
echo "→ log: $HOME/Library/Logs/MacKey68.log"
echo "Gỡ: launchctl bootout gui/$(id -u) $PLIST && rm -rf $DEST"
