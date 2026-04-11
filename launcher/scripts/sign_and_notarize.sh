#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCHER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$LAUNCHER_ROOT/dist"

APP_PATH="${1:-}"
DMG_PATH="${2:-}"

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

usage() {
  cat <<'EOF'
Usage:
  SIGN_IDENTITY="Developer ID Application: ..." \
  NOTARY_PROFILE="antigravity-notary" \
  bash scripts/sign_and_notarize.sh [app_path] [dmg_path]

Arguments (optional):
  app_path   Path to AntigravityProxyLauncher.app (default: latest Release app)
  dmg_path   Path to release dmg (default: latest in dist/)

Env:
  SIGN_IDENTITY   Developer ID Application identity
  NOTARY_PROFILE  xcrun notarytool keychain profile name

Prepare notary profile once:
  xcrun notarytool store-credentials antigravity-notary \
    --apple-id <APPLE_ID> --team-id <TEAM_ID> --password <APP_PASSWORD>
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "error: SIGN_IDENTITY is required"
  exit 1
fi

if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "error: NOTARY_PROFILE is required"
  exit 1
fi

if [[ -z "$APP_PATH" ]]; then
  APP_PATH="$LAUNCHER_ROOT/.build/xcode-release/Build/Products/Release/AntigravityProxyLauncher.app"
fi

if [[ -z "$DMG_PATH" ]]; then
  DMG_PATH="$(ls -t "$DIST_DIR"/*.dmg 2>/dev/null | head -n 1 || true)"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app bundle not found: $APP_PATH"
  exit 1
fi

if [[ -z "$DMG_PATH" || ! -f "$DMG_PATH" ]]; then
  echo "error: dmg not found: $DMG_PATH"
  exit 1
fi

echo "[1/5] Sign app bundle"
codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_PATH"

echo "[2/5] Verify app signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "[3/5] Submit app for notarization"
xcrun notarytool submit "$APP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "[4/5] Rebuild DMG with signed app"
TMP_DIR="$(mktemp -d /tmp/antigravity-signed.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT
cp -R "$APP_PATH" "$TMP_DIR/AntigravityProxyLauncher.app"
if [[ -f "$LAUNCHER_ROOT/.build/xcode-release/Build/Products/Release/AntigravityProxyLauncherCLI" ]]; then
  cp "$LAUNCHER_ROOT/.build/xcode-release/Build/Products/Release/AntigravityProxyLauncherCLI" "$TMP_DIR/AntigravityProxyLauncherCLI"
fi
SIGNED_DMG="$DIST_DIR/$(basename "$DMG_PATH" .dmg)-signed.dmg"
rm -f "$SIGNED_DMG"
hdiutil create -volname "Antigravity Proxy Launcher" -srcfolder "$TMP_DIR" -ov -format UDZO "$SIGNED_DMG" >/dev/null

echo "[5/5] Notarize and staple DMG"
xcrun notarytool submit "$SIGNED_DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$SIGNED_DMG"

echo "done"
echo "signed dmg: $SIGNED_DMG"
