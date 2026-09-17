#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d /private/tmp/screenpen-package-tests.XXXXXX)"
TEST_PROJECT="$TEST_ROOT/project"
FAKE_BIN="$TEST_ROOT/fake-bin"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || fail "expected output not to contain: $needle"
}

mkdir -p "$TEST_PROJECT/scripts" "$TEST_PROJECT/bin" "$FAKE_BIN"
cp "$PROJECT_ROOT/scripts/package-dmg.sh" "$TEST_PROJECT/scripts/package-dmg.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_PROJECT/bin/ScreenPen"
chmod +x "$TEST_PROJECT/bin/ScreenPen"

cat > "$FAKE_BIN/swift" <<'SCRIPT'
#!/usr/bin/env bash
if [[ " $* " == *" --show-bin-path "* ]]; then
  printf '%s\n' "$TEST_PROJECT/bin"
fi
SCRIPT

cat > "$FAKE_BIN/codesign" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT

cat > "$FAKE_BIN/security" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT

cat > "$FAKE_BIN/hdiutil" <<'SCRIPT'
#!/usr/bin/env bash
output_path=""
for argument in "$@"; do
  output_path="$argument"
done
touch "$output_path"
SCRIPT

cat > "$FAKE_BIN/xcrun" <<'SCRIPT'
#!/usr/bin/env bash
printf 'xcrun'
printf ' %q' "$@"
printf '\n'
SCRIPT

chmod +x \
  "$FAKE_BIN/swift" \
  "$FAKE_BIN/codesign" \
  "$FAKE_BIN/security" \
  "$FAKE_BIN/hdiutil" \
  "$FAKE_BIN/xcrun"

export TEST_PROJECT
TEST_PATH="$FAKE_BIN:/usr/bin:/bin:/usr/sbin:/sbin"

release_output="$(
  PATH="$TEST_PATH" \
  SCREENPEN_SIGNING_IDENTITY='Developer ID Application: Example Developer (TEAM123456)' \
  SCREENPEN_NOTARY_PROFILE='ScreenPen-notary' \
  bash "$TEST_PROJECT/scripts/package-dmg.sh" release --dry-run 2>&1
)"

assert_contains "$release_output" "MODE=release"
assert_contains "$release_output" "codesign --force --options runtime --timestamp"
assert_contains "$release_output" "xcrun notarytool submit"
assert_contains "$release_output" "xcrun stapler staple"
assert_contains "$release_output" "spctl --assess"
assert_contains "$release_output" "--timeout 2h"
assert_contains "$release_output" "DMG_WINDOW_SIZE=680x420"
assert_contains "$release_output" "DMG_ICON_SIZE=128"
assert_contains "$release_output" "create-dmg-layout.sh"
assert_contains "$release_output" "ScreenPen.icns"
assert_contains "$release_output" "ScreenPen_ScreenPen.bundle"

timeout_override_output="$(
  PATH="$TEST_PATH" \
  SCREENPEN_SIGNING_IDENTITY='Developer ID Application: Example Developer (TEAM123456)' \
  SCREENPEN_NOTARY_PROFILE='ScreenPen-notary' \
  SCREENPEN_NOTARY_TIMEOUT='45m' \
  bash "$TEST_PROJECT/scripts/package-dmg.sh" release --dry-run 2>&1
)"

assert_contains "$timeout_override_output" "--timeout 45m"

set +e
missing_output="$(
  PATH="$TEST_PATH" \
  env -u SCREENPEN_SIGNING_IDENTITY -u SCREENPEN_NOTARY_PROFILE \
  bash "$TEST_PROJECT/scripts/package-dmg.sh" release --dry-run 2>&1
)"
missing_status=$?
set -e

[[ "$missing_status" -ne 0 ]] || fail "release dry-run must reject missing signing configuration"
assert_contains "$missing_output" "SCREENPEN_SIGNING_IDENTITY"
assert_contains "$missing_output" "SCREENPEN_NOTARY_PROFILE"

local_output="$(
  PATH="$TEST_PATH" \
  bash "$TEST_PROJECT/scripts/package-dmg.sh" local --dry-run 2>&1
)"

assert_contains "$local_output" "MODE=local"
assert_contains "$local_output" "codesign --force --sign -"
assert_contains "$local_output" "DMG_WINDOW_SIZE=680x420"
assert_contains "$local_output" "DMG_ICON_SIZE=128"
assert_contains "$local_output" "create-dmg-layout.sh"
assert_not_contains "$local_output" "notarytool submit"

CURSOR_RESOURCES="$PROJECT_ROOT/Sources/ScreenPen/Resources/Cursors"
[[ -f "$CURSOR_RESOURCES/cursor-pen.svg" ]] || fail "pen cursor artwork is missing"
[[ -f "$CURSOR_RESOURCES/cursor-highlighter.svg" ]] || fail "highlighter cursor artwork is missing"
[[ -f "$CURSOR_RESOURCES/cursor-eraser.svg" ]] || fail "eraser cursor artwork is missing"
[[ -f "$PROJECT_ROOT/THIRD_PARTY_NOTICES.md" ]] || fail "third-party cursor license notice is missing"
[[ ! -e "$PROJECT_ROOT/Sources/ScreenPen/Resources/Artwork/lecture-chan.png" ]] \
  || fail "character artwork must be removed from the clean interface"
if grep -R -q "lecture-chan\|mascotView\|sakuraPink" \
  "$PROJECT_ROOT/Sources/ScreenPen" \
  "$PROJECT_ROOT/scripts/generate-release-artwork.swift"; then
  fail "clean interface must not retain the character or decorative pastel theme"
fi

OVERLAY_SOURCE="$PROJECT_ROOT/Sources/ScreenPen/OverlayView.swift"
grep -q "override func resetCursorRects" "$OVERLAY_SOURCE" \
  || fail "overlay must register tool-specific cursor rectangles"
grep -q "DrawingCursorFactory.cursor(for: tool).set()" "$OVERLAY_SOURCE" \
  || fail "tool selection must apply its cursor immediately"
grep -q "overlayView.applyActiveCursor()" "$PROJECT_ROOT/Sources/ScreenPen/OverlayWindow.swift" \
  || fail "enabling overlay input must immediately refresh the selected tool cursor"
[[ -f "$PROJECT_ROOT/Sources/ScreenPen/AppResources.swift" ]] \
  || fail "packaged resources need a direct app-bundle lookup helper"
grep -q "AppResources.url" "$PROJECT_ROOT/Sources/ScreenPen/DrawingCursorFactory.swift" \
  || fail "cursor loading must use the packaged app resource helper"
if grep -q "Bundle.module" "$PROJECT_ROOT/Sources/ScreenPen/DrawingCursorFactory.swift"; then
  fail "cursor loading must not rely on SwiftPM's development-only bundle path"
fi

PALETTE_SOURCE="$PROJECT_ROOT/Sources/ScreenPen/ToolPaletteWindow.swift"
[[ -f "$PALETTE_SOURCE" ]] || fail "floating tool palette is missing"
grep -q "CompactPanelLayout.panelWidth" "$PALETTE_SOURCE" \
  || fail "tool palette must match the width of the right shortcut panel"
grep -q "gridFrames" "$PALETTE_SOURCE" \
  || fail "tool palette must use a compact multi-row grid instead of one long row"
grep -q "windowBackgroundColor" "$PALETTE_SOURCE" \
  || fail "tool palette must match the shortcut panel's restrained system tone"
grep -q "지우개" "$PALETTE_SOURCE" \
  || fail "tool palette must expose the eraser visibly"
grep -q "DrawingPalette" "$PALETTE_SOURCE" \
  || fail "tool palette must expose pen and highlighter color swatches"
grep -q "placeBelow" "$PALETTE_SOURCE" \
  || fail "tool palette must support placement below the right help panel"
grep -q "placeBelow(helpPanelWindow)" "$PROJECT_ROOT/Sources/ScreenPen/AppDelegate.swift" \
  || fail "app delegate must anchor the tool palette below the right help panel"
grep -q "toolPaletteWindow?.setVisible(isVisible)" "$PROJECT_ROOT/Sources/ScreenPen/AppDelegate.swift" \
  || fail "tool palette visibility must follow the help overlay toggle"
if grep -q "toolPaletteWindow?.setVisible(true)" "$PROJECT_ROOT/Sources/ScreenPen/AppDelegate.swift"; then
  fail "tool palette must not bypass the shared help overlay visibility state"
fi

HOT_KEY_SOURCE="$PROJECT_ROOT/Sources/ScreenPen/GlobalHotKeyMonitor.swift"
grep -q "kVK_Escape" "$HOT_KEY_SOURCE" \
  || fail "Escape must use a reliable Carbon hot key while a tool is active"
grep -q "setDeactivateHotKeyEnabled" "$HOT_KEY_SOURCE" \
  || fail "the global Escape hot key must only be active while ScreenPen is active"
grep -q "setDeactivateHotKeyEnabled" "$PROJECT_ROOT/Sources/ScreenPen/AppDelegate.swift" \
  || fail "app state changes must update the global Escape hot key"

HELP_SOURCE="$PROJECT_ROOT/Sources/ScreenPen/HelpPanelWindow.swift"
grep -q "macOS 내장 확대" "$HELP_SOURCE" \
  || fail "help panel must explain the native macOS zoom behavior"

SYSTEM_ZOOM_SOURCE="$PROJECT_ROOT/Sources/ScreenPen/MacSystemZoomController.swift"
[[ -f "$SYSTEM_ZOOM_SOURCE" ]] || fail "native macOS zoom controller is missing"
grep -q "CGEvent" "$SYSTEM_ZOOM_SOURCE" \
  || fail "native zoom controller must invoke the macOS accessibility shortcut"
grep -q "com.apple.Accessibility-Settings.extension?Seeing_Zoom" "$SYSTEM_ZOOM_SOURCE" \
  || fail "native zoom controller must provide an Accessibility Zoom settings shortcut"
if grep -q "ScreenCaptureCoordinator" "$PROJECT_ROOT/Sources/ScreenPen/AppDelegate.swift"; then
  fail "app delegate must not depend on screen recording for zoom"
fi
[[ ! -f "$PROJECT_ROOT/Sources/ScreenPen/MagnifierSupport.swift" ]] \
  || fail "obsolete screen-recording magnifier source must be removed"

grep -q "macOS 내장 확대" "$PROJECT_ROOT/README.md" \
  || fail "README must explain the native macOS zoom"
grep -q "색상 원" "$PROJECT_ROOT/README.md" \
  || fail "README must explain how to change pen and highlighter colors"
if grep -q "ScreenCaptureKit" "$PROJECT_ROOT/README.md"; then
  fail "README must not instruct users to grant screen-recording permission"
fi

SETUP_SCRIPT="$PROJECT_ROOT/scripts/setup-notarization-profile.sh"
[[ -f "$SETUP_SCRIPT" ]] || fail "setup-notarization-profile.sh is missing"

set +e
setup_missing_output="$(
  PATH="$TEST_PATH" \
  env -u SCREENPEN_APPLE_ID -u SCREENPEN_TEAM_ID \
  bash "$SETUP_SCRIPT" 2>&1
)"
setup_missing_status=$?
set -e

[[ "$setup_missing_status" -ne 0 ]] || fail "notarization setup must reject missing account configuration"
assert_contains "$setup_missing_output" "SCREENPEN_APPLE_ID"
assert_contains "$setup_missing_output" "SCREENPEN_TEAM_ID"

setup_output="$(
  PATH="$TEST_PATH" \
  SCREENPEN_APPLE_ID='developer@example.com' \
  SCREENPEN_TEAM_ID='TEAM123456' \
  bash "$SETUP_SCRIPT" 2>&1
)"

assert_contains "$setup_output" "xcrun notarytool store-credentials ScreenPen-notary"
assert_contains "$setup_output" "--apple-id developer@example.com"
assert_contains "$setup_output" "--team-id TEAM123456"
assert_not_contains "$setup_output" "--password"

printf 'PASS: package-dmg release pipeline tests\n'
