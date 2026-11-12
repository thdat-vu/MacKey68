#!/usr/bin/env bash
# Notarize and staple a signed DMG.
# Local:   xcrun notarytool store-credentials mackey68-notary --apple-id ... --team-id ... --password ...
#          ./scripts/notarize.sh dist/MacKey68-0.5.0.dmg
# CI:      APPLE_ID / TEAM_ID / APP_PASSWORD set in the environment.
set -euo pipefail
cd "$(dirname "$0")/.."

DMG="${1:?usage: notarize.sh <path-to-dmg>}"
PROFILE="${MACKEY_NOTARY_PROFILE:-mackey68-notary}"

if [[ -n "${APPLE_ID:-}" && -n "${TEAM_ID:-}" && -n "${APP_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$DMG" \
        --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$APP_PASSWORD" \
        --wait
else
    xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
fi

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl -a -vv -t open --context context:primary-signature "$DMG" || true
echo "→ notarized and stapled: $DMG"
