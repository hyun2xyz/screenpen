#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ScreenPen"
VERSION="${SCREENPEN_VERSION:-1.0.0}"
BUILD_NUMBER="${SCREENPEN_BUILD_NUMBER:-1}"
BUNDLE_ID="${SCREENPEN_BUNDLE_ID:-xyz.iyo.ScreenPen}"
MODE="${1:-local}"
DRY_RUN=false

if [[ $# -gt 0 ]]; then
  shift
fi

for argument in "$@"; do
  case "$argument" in
    --dry-run)
      DRY_RUN=true
      ;;
    -h|--help)
      cat <<'USAGE'
Usage:
  ./scripts/package-dmg.sh local [--dry-run]
  ./scripts/package-dmg.sh release [--dry-run]

Modes:
  local    Build an ad-hoc-signed app and DMG for this Mac.
  release  Developer ID sign, notarize, staple, and Gatekeeper-check the app and DMG.

Release environment:
  SCREENPEN_SIGNING_IDENTITY  Full "Developer ID Application: ..." identity.
                               If omitted, the script auto-selects a single installed identity.
  SCREENPEN_NOTARY_PROFILE    Keychain profile created by notarytool store-credentials.

Optional environment:
  SCREENPEN_VERSION           Marketing version. Default: 1.0.0
  SCREENPEN_BUILD_NUMBER      Bundle build number. Default: 1
  SCREENPEN_BUNDLE_ID         Bundle identifier. Default: xyz.iyo.ScreenPen
  SCREENPEN_NOTARY_TIMEOUT    Per-submission wait limit. Default: 2h
USAGE
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$argument" >&2
      exit 2
      ;;
  esac
done

case "$MODE" in
  local|release)
    ;;
  -h|--help)
    "$0" local --help
    exit 0
    ;;
  *)
    printf 'Unknown mode: %s (expected local or release)\n' "$MODE" >&2
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"
BUILD_DIR="$PROJECT_ROOT/.build"
APP_PATH="$DIST_DIR/$APP_NAME.app"
STAGING_DIR="$BUILD_DIR/dmg-staging"
NOTARY_DIR="$BUILD_DIR/notarization"
ARTWORK_DIR="$BUILD_DIR/release-artwork"
ZIP_PATH="$NOTARY_DIR/$APP_NAME-$VERSION.zip"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
APP_NOTARY_RESULT="$DIST_DIR/$APP_NAME-$VERSION-app-notary.json"
DMG_NOTARY_RESULT="$DIST_DIR/$APP_NAME-$VERSION-dmg-notary.json"
ARTWORK_GENERATOR="$SCRIPT_DIR/generate-release-artwork.swift"
DMG_LAYOUT_SCRIPT="$SCRIPT_DIR/create-dmg-layout.sh"
ICONSET_PATH="$ARTWORK_DIR/$APP_NAME.iconset"
APP_ICON_PATH="$ARTWORK_DIR/$APP_NAME.icns"
DMG_BACKGROUND_PATH="$ARTWORK_DIR/$APP_NAME-dmg-background.png"
RESOURCE_BUNDLE_NAME="${APP_NAME}_${APP_NAME}.bundle"

SIGNING_IDENTITY="${SCREENPEN_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${SCREENPEN_NOTARY_PROFILE:-}"
NOTARY_TIMEOUT="${SCREENPEN_NOTARY_TIMEOUT:-2h}"

find_signing_identity() {
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/^.*"\(Developer ID Application: [^"]*\)".*$/\1/p'
}

if [[ "$MODE" == "release" && -z "$SIGNING_IDENTITY" ]]; then
  installed_identities="$(find_signing_identity)"
  if [[ -n "$installed_identities" && "$installed_identities" != *$'\n'* ]]; then
    SIGNING_IDENTITY="$installed_identities"
  fi
fi

if [[ "$MODE" == "release" ]]; then
  missing_configuration=()
  [[ -n "$SIGNING_IDENTITY" ]] || missing_configuration+=("SCREENPEN_SIGNING_IDENTITY")
  [[ -n "$NOTARY_PROFILE" ]] || missing_configuration+=("SCREENPEN_NOTARY_PROFILE")

  if [[ "${#missing_configuration[@]}" -gt 0 ]]; then
    printf 'Release configuration is missing: %s\n' "${missing_configuration[*]}" >&2
    printf 'Install a Developer ID Application certificate and create a notarytool Keychain profile first.\n' >&2
    exit 2
  fi
fi

print_command() {
  printf '  '
  printf '%q ' "$@"
  printf '\n'
}

print_plan() {
  printf 'MODE=%s\n' "$MODE"
  printf 'APP=%s\n' "$APP_PATH"
  printf 'DMG=%s\n' "$DMG_PATH"
  printf 'DMG_WINDOW_SIZE=680x420\n'
  printf 'DMG_ICON_SIZE=128\n'
  print_command swift build -c release --product "$APP_NAME"
  print_command swift "$ARTWORK_GENERATOR" "$ARTWORK_DIR"
  print_command iconutil -c icns "$ICONSET_PATH" -o "$APP_ICON_PATH"
  print_command ditto "$RESOURCE_BUNDLE_NAME" "$APP_PATH/Contents/Resources/$RESOURCE_BUNDLE_NAME"
  print_command cp "$APP_ICON_PATH" "$APP_PATH/Contents/Resources/$APP_NAME.icns"
  print_command "$DMG_LAYOUT_SCRIPT" "$APP_NAME" "$APP_NAME" "$STAGING_DIR" "$DMG_PATH"

  if [[ "$MODE" == "release" ]]; then
    printf 'SIGNING_IDENTITY=%s\n' "$SIGNING_IDENTITY"
    printf 'NOTARY_PROFILE=%s\n' "$NOTARY_PROFILE"
    print_command codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_PATH"
    print_command ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
    print_command xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait --timeout "$NOTARY_TIMEOUT"
    print_command xcrun stapler staple -v "$APP_PATH"
    print_command codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
    print_command xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait --timeout "$NOTARY_TIMEOUT"
    print_command xcrun stapler staple -v "$DMG_PATH"
    print_command spctl --assess --type execute --verbose=4 "$APP_PATH"
    print_command spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
  else
    print_command codesign --force --sign - "$APP_PATH"
  fi
}

if "$DRY_RUN"; then
  print_plan
  exit 0
fi

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Required command not found: %s\n' "$1" >&2
    exit 127
  }
}

require_command swift
require_command codesign
require_command ditto
require_command hdiutil
require_command iconutil
require_command osascript
require_command SetFile

if [[ "$MODE" == "release" ]]; then
  require_command xcrun
  require_command spctl
fi

cd "$PROJECT_ROOT"

swift build -c release --product "$APP_NAME"
BIN_DIR="$(swift build -c release --show-bin-path)"
RESOURCE_BUNDLE_PATH="$BIN_DIR/$RESOURCE_BUNDLE_NAME"

rm -rf "$APP_PATH" "$STAGING_DIR" "$NOTARY_DIR" "$ARTWORK_DIR" "$DMG_PATH"
rm -f "$APP_NOTARY_RESULT" "$DMG_NOTARY_RESULT"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$STAGING_DIR" "$NOTARY_DIR"

swift "$ARTWORK_GENERATOR" "$ARTWORK_DIR"
iconutil -c icns "$ICONSET_PATH" -o "$APP_ICON_PATH"

cp "$BIN_DIR/$APP_NAME" "$APP_PATH/Contents/MacOS/$APP_NAME"
chmod 755 "$APP_PATH/Contents/MacOS/$APP_NAME"
[[ -d "$RESOURCE_BUNDLE_PATH" ]] || {
  printf 'Swift Package resource bundle is missing: %s\n' "$RESOURCE_BUNDLE_PATH" >&2
  exit 1
}
ditto "$RESOURCE_BUNDLE_PATH" "$APP_PATH/Contents/Resources/$RESOURCE_BUNDLE_NAME"
cp "$APP_ICON_PATH" "$APP_PATH/Contents/Resources/$APP_NAME.icns"

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"

if [[ "$MODE" == "release" ]]; then
  codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$SIGNING_IDENTITY" \
    "$APP_PATH"
else
  codesign --force --sign - "$APP_PATH"
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if [[ "$MODE" == "release" ]]; then
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
  xcrun notarytool submit \
    "$ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait \
    --timeout "$NOTARY_TIMEOUT" \
    --output-format json \
    > "$APP_NOTARY_RESULT"
  cat "$APP_NOTARY_RESULT"

  app_notary_status="$(plutil -extract status raw -o - "$APP_NOTARY_RESULT")"
  if [[ "$app_notary_status" != "Accepted" ]]; then
    printf 'App notarization failed with status: %s\n' "$app_notary_status" >&2
    exit 1
  fi

  xcrun stapler staple -v "$APP_PATH"
  xcrun stapler validate -v "$APP_PATH"
fi

ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
mkdir -p "$STAGING_DIR/.background"
cp "$DMG_BACKGROUND_PATH" "$STAGING_DIR/.background/$(basename "$DMG_BACKGROUND_PATH")"
cp "$APP_ICON_PATH" "$STAGING_DIR/.VolumeIcon.icns"

"$DMG_LAYOUT_SCRIPT" "$APP_NAME" "$APP_NAME" "$STAGING_DIR" "$DMG_PATH"

if [[ "$MODE" == "release" ]]; then
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
  codesign --verify --strict --verbose=2 "$DMG_PATH"

  xcrun notarytool submit \
    "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait \
    --timeout "$NOTARY_TIMEOUT" \
    --output-format json \
    > "$DMG_NOTARY_RESULT"
  cat "$DMG_NOTARY_RESULT"

  dmg_notary_status="$(plutil -extract status raw -o - "$DMG_NOTARY_RESULT")"
  if [[ "$dmg_notary_status" != "Accepted" ]]; then
    printf 'DMG notarization failed with status: %s\n' "$dmg_notary_status" >&2
    exit 1
  fi

  xcrun stapler staple -v "$DMG_PATH"
  xcrun stapler validate -v "$DMG_PATH"
  spctl --assess --type execute --verbose=4 "$APP_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
fi

hdiutil verify "$DMG_PATH"

printf '%s\n' "$DMG_PATH"
