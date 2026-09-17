# ScreenPen Apple Developer Release Setup

This setup is for distributing ScreenPen outside the Mac App Store with Developer ID.
It is a one-time setup per development Mac.

## What To Provide

Provide only these non-secret details:

1. **Developer Team ID** — the 10-character value in the Apple Developer membership details.
2. **Apple ID email** used by the Apple Developer account.
3. Confirmation that a **Developer ID Application** certificate is installed in this Mac's
   login Keychain and appears under **My Certificates** with its private key.
4. Confirmation that the `ScreenPen-notary` Keychain profile was stored successfully.

Do **not** paste or upload any of these into chat, Git, or the project:

- Apple ID password
- App-specific password
- `.p8` API private key contents
- `.p12` certificate or certificate private key
- Keychain export

ScreenPen does not need an App Store Connect API key for this single-Mac workflow.
An API key is better reserved for a future CI release machine.

## 1. Create And Install The Developer ID Certificate

1. On this Mac, open **Keychain Access**.
2. Choose **Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority**.
3. Enter the Apple Developer account email and a recognizable common name.
4. Select **Saved to disk** and create the `.certSigningRequest` file.
5. Open [Apple Developer Certificates](https://developer.apple.com/account/resources/certificates/list).
6. Click **+**, select **Developer ID**, then select **Developer ID Application**.
7. Upload the `.certSigningRequest`, download the resulting `.cer`, and double-click it.
8. In Keychain Access, verify it appears in **login → My Certificates** and expands to show
   a private key.

Never create the CSR on one Mac and install only the `.cer` on another Mac. The matching
private key remains on the Mac that created the CSR.

Verify from Terminal:

```bash
security find-identity -v -p codesigning
```

The result must include exactly one usable identity similar to:

```text
Developer ID Application: Your Name (ABCDE12345)
```

Copying the identity's visible name is safe. Do not export or share its private key.

## 2. Create An Apple App-Specific Password

1. Open [Apple Account Sign-In and Security](https://account.apple.com/account/manage).
2. Create an **app-specific password** for `ScreenPen notarization`.
3. Keep it private. It is entered once into a secure Terminal prompt and then stored in Keychain.

## 3. Store The Notarization Credential In Keychain

From the ScreenPen project:

```bash
cd /Users/han/Documents/ScreenPen

SCREENPEN_APPLE_ID='you@example.com' \
SCREENPEN_TEAM_ID='ABCDE12345' \
./scripts/setup-notarization-profile.sh
```

`notarytool` asks for the app-specific password securely. The script deliberately has no
password environment variable or command-line option, so the password does not enter shell
history or project files.

The stored profile name is:

```text
ScreenPen-notary
```

## 4. Check The Release Plan

```bash
SCREENPEN_NOTARY_PROFILE='ScreenPen-notary' \
./scripts/package-dmg.sh release --dry-run
```

If exactly one Developer ID Application identity is installed, the script selects it
automatically. Otherwise set the full identity explicitly:

```bash
SCREENPEN_SIGNING_IDENTITY='Developer ID Application: Your Name (ABCDE12345)' \
SCREENPEN_NOTARY_PROFILE='ScreenPen-notary' \
./scripts/package-dmg.sh release --dry-run
```

## 5. Build, Sign, Notarize, And Staple

```bash
SCREENPEN_SIGNING_IDENTITY='Developer ID Application: Your Name (ABCDE12345)' \
SCREENPEN_NOTARY_PROFILE='ScreenPen-notary' \
./scripts/package-dmg.sh release
```

Each Apple submission waits for up to two hours by default. Override that limit when needed:

```bash
SCREENPEN_NOTARY_TIMEOUT='3h' \
SCREENPEN_NOTARY_PROFILE='ScreenPen-notary' \
./scripts/package-dmg.sh release
```

If a wait limit is reached, Apple continues processing the existing submission. Check its
ID with `xcrun notarytool history --keychain-profile ScreenPen-notary` and resume waiting
with `xcrun notarytool wait SUBMISSION_ID --keychain-profile ScreenPen-notary`.
Do not upload duplicate submissions just because the local wait ended.

The release script:

1. Builds the Release executable.
2. Creates `ScreenPen.app`.
3. Signs the app with Developer ID, hardened runtime, and Apple timestamp.
4. Uploads a ZIP of the app to Apple's notary service.
5. Staples and validates the app ticket.
6. Builds and signs `ScreenPen-1.0.0.dmg`.
7. Notarizes, staples, and validates the DMG.
8. Runs Gatekeeper, code-signing, and disk-image integrity checks.

Successful output is written to:

```text
/Users/han/Documents/ScreenPen/dist/ScreenPen.app
/Users/han/Documents/ScreenPen/dist/ScreenPen-1.0.0.dmg
```

The notarization result JSON files remain in `dist/` as release evidence. The folder is
ignored by Git.

## Official Apple References

- [Create Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
