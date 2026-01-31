#!/bin/bash
set -e

APP_NAME="Antigravity"
SRC_APP="/Applications/${APP_NAME}.app"
DEST_APP="./${APP_NAME}_Unlocked.app"
ENTITLEMENTS="./entitlements.plist"

echo "[*] Robust Unlocking ${APP_NAME}.app..."

# 1. Clean copy
if [ -d "$DEST_APP" ]; then
    echo "[-] Removing existing unlocked app..."
    rm -rf "$DEST_APP"
fi

echo "[*] Copying app to local directory..."
cp -R "$SRC_APP" "$DEST_APP"

echo "[*] Cleaning extended attributes..."
xattr -cr "$DEST_APP"

# 2. Define signing function
sign_component() {
    local path="$1"
    echo "    Signing: $path"
    # Remove existing signature
    codesign --remove-signature "$path" 2>/dev/null || true
    # Sign with entitlements
    codesign --force --options runtime --sign - --entitlements "$ENTITLEMENTS" "$path"
}

export -f sign_component
export ENTITLEMENTS

echo "[*] Recursively signing nested components (Inside-Out)..."

# Find all nested frameworks, dylibs, and helpers
# Depth-first order is important (deepest first)
# Find all files, check if they are Mach-O binaries, and sign them deep-first
find "$DEST_APP/Contents" -type f | while read -r file; do
    if file "$file" | grep -q "Mach-O"; then
        echo "$file"
    fi
done | awk '{ print length, $0 }' | sort -rn | cut -d" " -f2- | while read -r binary; do
    sign_component "$binary"
done

echo "[*] Signing Main Executable..."
sign_component "$DEST_APP/Contents/MacOS/Electron"

# Finally sign the top-level bundle
echo "[*] Signing App Bundle..."
codesign --force --options runtime --sign - --entitlements "$ENTITLEMENTS" "$DEST_APP"

echo "[SUCCESS] Robust unlock complete at: $DEST_APP"
