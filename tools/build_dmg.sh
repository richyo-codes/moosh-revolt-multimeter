#!/usr/bin/env bash
# Builds a drag-to-install disk image of the macOS app:
#   build/MooshRevolt-<version>-macos.dmg (+ .sha256)
#
# The image holds MooshRevolt.app and a link to /Applications. Without a
# signing identity the app keeps Flutter's ad-hoc signature, and macOS asks
# users to allow it once under System Settings → Privacy & Security.
#
# Optional environment:
#   SKIP_BUILD=1        reuse an existing release build
#   SIGN_IDENTITY       "Developer ID Application: …" to sign app and image
#   NOTARY_PROFILE      notarytool keychain profile to notarize and staple
#                       (create one with `xcrun notarytool store-credentials`)
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME=MooshRevolt
APP="build/macos/Build/Products/Release/${APP_NAME}.app"
VERSION=$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)
DMG="build/${APP_NAME}-${VERSION}-macos.dmg"

if [[ "${SKIP_BUILD:-0}" != 1 ]]; then
  flutter build macos --release
fi
test -d "$APP"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  echo "Signing ${APP_NAME}.app with ${SIGN_IDENTITY}"
  codesign --force --deep --options runtime --timestamp \
    --entitlements macos/Runner/Release.entitlements \
    --sign "$SIGN_IDENTITY" "$APP"
fi

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# Show the app icon on the mounted volume when the tools are available.
ICON="$APP/Contents/Resources/AppIcon.icns"
if [[ -f "$ICON" ]] && command -v SetFile >/dev/null; then
  cp "$ICON" "$STAGE/.VolumeIcon.icns"
  SetFile -a C "$STAGE"
fi

rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -fs HFS+ \
  -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "Notarizing $DMG"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

(cd build && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "Built $DMG"
