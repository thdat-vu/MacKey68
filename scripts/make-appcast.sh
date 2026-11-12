#!/usr/bin/env bash
# Build appcast.xml for Sparkle from the DMG and its EdDSA key.
#   ./scripts/make-appcast.sh [dist/MacKey68-0.5.0.dmg]
# Signing key: $SPARKLE_PRIVATE_KEY_FILE (default ~/.config/mackey/sparkle_private_key)
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/MacKey68.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
DMG="${1:-dist/MacKey68-$VERSION.dmg}"
KEY="${SPARKLE_PRIVATE_KEY_FILE:-$HOME/.config/mackey/sparkle_private_key}"
SIGN_UPDATE=".build/artifacts/sparkle/Sparkle/bin/sign_update"

[[ -f "$DMG" ]] || { echo "missing $DMG" >&2; exit 1; }
[[ -f "$KEY" ]] || { echo "missing Sparkle private key: $KEY" >&2; exit 1; }
[[ -x "$SIGN_UPDATE" ]] || { echo "Sparkle tools not resolved; run swift package resolve" >&2; exit 1; }

SIGNATURE="$("$SIGN_UPDATE" --ed-key-file "$KEY" "$DMG")"
URL="https://github.com/thdat-vu/MacKey68/releases/download/v$VERSION/$(basename "$DMG")"
DATE="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"

cat > appcast.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>MacKey68</title>
    <link>https://github.com/thdat-vu/MacKey68</link>
    <description>Menu-bar keyboard remapper for macOS</description>
    <language>en</language>
    <item>
      <title>MacKey68 $VERSION</title>
      <pubDate>$DATE</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <enclosure url="$URL"
                 $SIGNATURE
                 type="application/octet-stream"/>
    </item>
  </channel>
</rss>
EOF

echo "→ appcast.xml ($VERSION / build $BUILD)"
