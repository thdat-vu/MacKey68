#!/usr/bin/env bash
# Cập nhật version + SHA-256 trong Casks/mackey68.rb từ DMG mới nhất.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/MacKey68.app/Contents/Info.plist)"
DMG="dist/MacKey68-$VERSION.dmg"
[[ -f "$DMG" ]] || { echo "missing $DMG — chạy ./scripts/package-dmg.sh trước" >&2; exit 1; }

SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
CASKS="Casks/mackey68.rb"
sed -i '' -E "s/^  version \".*\"/  version \"$VERSION\"/" "$CASKS"
sed -i '' -E "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASKS"
echo "→ $CASKS: $VERSION / $SHA"
