#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  printf 'Usage: %s <volume-name> <app-name> <staging-directory> <output.dmg>\n' "$0" >&2
  exit 2
fi

VOLUME_NAME="$1"
APP_NAME="$2"
STAGING_DIR="$3"
OUTPUT_DMG="$4"

WINDOW_WIDTH=680
WINDOW_HEIGHT=420
ICON_SIZE=128
APP_X=180
APP_Y=225
APPLICATIONS_X=500
APPLICATIONS_Y=225
BACKGROUND_FILE="ScreenPen-dmg-background.png"

for command_name in hdiutil osascript SetFile; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Required command not found: %s\n' "$command_name" >&2
    exit 127
  }
done

[[ -d "$STAGING_DIR" ]] || {
  printf 'DMG staging directory does not exist: %s\n' "$STAGING_DIR" >&2
  exit 2
}
[[ -d "$STAGING_DIR/$APP_NAME.app" ]] || {
  printf 'App bundle is missing from DMG staging: %s.app\n' "$APP_NAME" >&2
  exit 2
}
[[ -L "$STAGING_DIR/Applications" ]] || {
  printf 'Applications link is missing from DMG staging.\n' >&2
  exit 2
}
[[ -f "$STAGING_DIR/.background/$BACKGROUND_FILE" ]] || {
  printf 'DMG background is missing: %s\n' "$BACKGROUND_FILE" >&2
  exit 2
}

WORK_DIR="$(mktemp -d "${TMPDIR:-/private/tmp}/screenpen-dmg-layout.XXXXXX")"
READ_WRITE_DMG="$WORK_DIR/ScreenPen-writable.dmg"
MOUNT_DIR="$WORK_DIR/mount"
ATTACHED_DEVICE=""

cleanup() {
  if [[ -n "$ATTACHED_DEVICE" ]]; then
    hdiutil detach "$ATTACHED_DEVICE" -force >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$MOUNT_DIR"
rm -f "$OUTPUT_DMG"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "$READ_WRITE_DMG"

attach_output="$(
  hdiutil attach \
    -readwrite \
    -noverify \
    -noautoopen \
    -mountpoint "$MOUNT_DIR" \
    "$READ_WRITE_DMG"
)"
ATTACHED_DEVICE="$(printf '%s\n' "$attach_output" | awk '/^\/dev\// { print $1; exit }')"
[[ -n "$ATTACHED_DEVICE" ]] || {
  printf 'Could not determine the attached DMG device.\n' >&2
  exit 1
}

SetFile -a V "$MOUNT_DIR/.background"
if [[ -f "$MOUNT_DIR/.VolumeIcon.icns" ]]; then
  SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns"
  SetFile -a C "$MOUNT_DIR"
fi

osascript - \
  "$MOUNT_DIR" \
  "$APP_NAME.app" \
  "$WINDOW_WIDTH" \
  "$WINDOW_HEIGHT" \
  "$ICON_SIZE" \
  "$APP_X" \
  "$APP_Y" \
  "$APPLICATIONS_X" \
  "$APPLICATIONS_Y" \
  "$BACKGROUND_FILE" <<'APPLESCRIPT'
on run arguments
  set mountPath to item 1 of arguments
  set appFileName to item 2 of arguments
  set windowWidth to (item 3 of arguments) as integer
  set windowHeight to (item 4 of arguments) as integer
  set iconSize to (item 5 of arguments) as integer
  set appX to (item 6 of arguments) as integer
  set appY to (item 7 of arguments) as integer
  set applicationsX to (item 8 of arguments) as integer
  set applicationsY to (item 9 of arguments) as integer
  set backgroundFileName to item 10 of arguments

  tell application "Finder"
    set mountedFolder to POSIX file mountPath as alias
    set backgroundFile to POSIX file (mountPath & "/.background/" & backgroundFileName) as alias
    open mountedFolder
    delay 1

    set installerWindow to container window of mountedFolder
    set current view of installerWindow to icon view
    set toolbar visible of installerWindow to false
    set statusbar visible of installerWindow to false
    set bounds of installerWindow to {120, 120, 120 + windowWidth, 120 + windowHeight}

    set viewOptions to icon view options of installerWindow
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to iconSize
    set text size of viewOptions to 14
    set background picture of viewOptions to backgroundFile

    set position of item appFileName of mountedFolder to {appX, appY}
    set position of item "Applications" of mountedFolder to {applicationsX, applicationsY}

    update mountedFolder without registering applications
    delay 2
    close installerWindow
  end tell
end run
APPLESCRIPT

sync
hdiutil detach "$ATTACHED_DEVICE"
ATTACHED_DEVICE=""

hdiutil convert \
  "$READ_WRITE_DMG" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$OUTPUT_DMG"

hdiutil verify "$OUTPUT_DMG"
