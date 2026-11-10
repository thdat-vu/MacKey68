#!/usr/bin/env bash
# Tạo Assets/AppIcon.icns từ script vẽ icon (không cần file ảnh nguồn).
set -euo pipefail
cd "$(dirname "$0")/.."

swift scripts/make-icon.swift

ICONSET="Assets/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Assets/AppIcon-1024.png \
        --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" Assets/AppIcon-1024.png \
        --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o Assets/AppIcon.icns
rm -rf "$ICONSET"

echo "→ Assets/AppIcon.icns"
