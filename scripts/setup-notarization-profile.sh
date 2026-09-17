#!/usr/bin/env bash
set -euo pipefail

PROFILE_NAME="${SCREENPEN_NOTARY_PROFILE:-ScreenPen-notary}"
APPLE_ID="${SCREENPEN_APPLE_ID:-}"
TEAM_ID="${SCREENPEN_TEAM_ID:-}"

if [[ -z "$APPLE_ID" || -z "$TEAM_ID" ]]; then
  cat <<'USAGE' >&2
Set the Apple ID email and Developer Team ID, then run this script:

  SCREENPEN_APPLE_ID='you@example.com' \
  SCREENPEN_TEAM_ID='ABCDE12345' \
  ./scripts/setup-notarization-profile.sh

The script never accepts the app-specific password as an environment variable.
notarytool asks for it securely and stores the validated credential in Keychain.
USAGE
  exit 2
fi

xcrun notarytool store-credentials \
  "$PROFILE_NAME" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID"

printf 'Stored notarization profile: %s\n' "$PROFILE_NAME"
