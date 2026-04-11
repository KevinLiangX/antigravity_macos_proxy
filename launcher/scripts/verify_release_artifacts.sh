#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCHER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$LAUNCHER_ROOT/dist"

ZIP_PATH="${1:-}"
DMG_PATH="${2:-}"

if [[ -z "$ZIP_PATH" ]]; then
  ZIP_PATH="$(ls -t "$DIST_DIR"/*.zip 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$DMG_PATH" ]]; then
  DMG_PATH="$(ls -t "$DIST_DIR"/*.dmg 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$ZIP_PATH" || ! -f "$ZIP_PATH" ]]; then
  echo "error: zip artifact not found"
  exit 1
fi

if [[ -z "$DMG_PATH" || ! -f "$DMG_PATH" ]]; then
  echo "error: dmg artifact not found"
  exit 1
fi

echo "[1/4] Validate ZIP content"
REQUIRED_ZIP_ENTRIES=(
  "AntigravityProxyLauncher.app/Contents/MacOS/AntigravityProxyLauncher"
  "AntigravityProxyLauncher.app/Contents/Resources/libAntigravityTun.dylib"
  "AntigravityProxyLauncher.app/Contents/Resources/proxy_config.template.json"
  "AntigravityProxyLauncher.app/Contents/Resources/entitlements.plist"
  "AntigravityProxyLauncher.app/Contents/Resources/compatibility.json"
)

ZIP_LIST="$(unzip -Z1 "$ZIP_PATH")"
for entry in "${REQUIRED_ZIP_ENTRIES[@]}"; do
  if ! printf '%s\n' "$ZIP_LIST" | grep -Fxq "$entry"; then
    echo "error: missing zip entry: $entry"
    exit 1
  fi
done

echo "[2/4] Verify DMG integrity"
hdiutil verify "$DMG_PATH" >/dev/null

MOUNT_DIR="$(mktemp -d /tmp/antigravity-release-check.XXXXXX)"
ATTACHED=0

cleanup() {
  if [[ "$ATTACHED" -eq 1 ]]; then
    hdiutil detach "$MOUNT_DIR" -quiet || true
  fi
  rm -rf "$MOUNT_DIR"
}
trap cleanup EXIT

echo "[3/4] Validate DMG content"
hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_DIR" -quiet
ATTACHED=1

if [[ ! -d "$MOUNT_DIR/AntigravityProxyLauncher.app" ]]; then
  echo "error: DMG missing AntigravityProxyLauncher.app"
  exit 1
fi

if [[ ! -f "$MOUNT_DIR/AntigravityProxyLauncherCLI" ]]; then
  echo "error: DMG missing AntigravityProxyLauncherCLI"
  exit 1
fi

echo "[4/4] Write checksum manifest"
ZIP_SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
DMG_SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
STAMP="$(date +%Y%m%d-%H%M%S)"
MANIFEST_PATH="$DIST_DIR/release-checksums-$STAMP.json"

cat > "$MANIFEST_PATH" <<EOF
{
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "zip": {
    "path": "$(basename "$ZIP_PATH")",
    "sha256": "$ZIP_SHA256"
  },
  "dmg": {
    "path": "$(basename "$DMG_PATH")",
    "sha256": "$DMG_SHA256"
  }
}
EOF

echo "done"
echo "zip: $ZIP_PATH"
echo "dmg: $DMG_PATH"
echo "manifest: $MANIFEST_PATH"
