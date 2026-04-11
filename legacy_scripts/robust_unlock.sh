#!/bin/bash
set -e

APP_NAME="Antigravity"
SRC_APP="/Applications/${APP_NAME}.app"
DEST_APP="./${APP_NAME}_Unlocked.app"
ENTITLEMENTS="./entitlements.plist"
LOCAL_DYLIB="./libAntigravityTun.dylib"
LOCAL_CONFIG="./config.json"
LOCAL_CONFIG_FALLBACK="./proxy_config.json.example"
BUNDLE_DYLIB_REL="@executable_path/../Resources/libAntigravityTun.dylib"
BUNDLE_CONFIG_REL="@executable_path/../Resources/proxy_config.json"

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

echo "[*] Embedding proxy assets into app bundle..."
if [ ! -f "$LOCAL_DYLIB" ]; then
    echo "[Error] Missing dylib: $LOCAL_DYLIB"
    echo "        Please run ./compile_without_xcode.sh first."
    exit 1
fi

cp "$LOCAL_DYLIB" "$DEST_APP/Contents/Resources/libAntigravityTun.dylib"
if [ -f "$LOCAL_CONFIG" ]; then
    cp "$LOCAL_CONFIG" "$DEST_APP/Contents/Resources/proxy_config.json"
elif [ -f "$LOCAL_CONFIG_FALLBACK" ]; then
    cp "$LOCAL_CONFIG_FALLBACK" "$DEST_APP/Contents/Resources/proxy_config.json"
else
    echo "[Error] Missing config file: $LOCAL_CONFIG (or $LOCAL_CONFIG_FALLBACK)"
    exit 1
fi

echo "[*] Setting LSEnvironment for restart-safe injection..."
INFO_PLIST="$DEST_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSEnvironment dict" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :LSEnvironment:DYLD_INSERT_LIBRARIES" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :LSEnvironment:ANTIGRAVITY_CONFIG" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :LSEnvironment:DYLD_INSERT_LIBRARIES string $BUNDLE_DYLIB_REL" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :LSEnvironment:ANTIGRAVITY_CONFIG string $BUNDLE_CONFIG_REL" "$INFO_PLIST"

echo "[*] Disabling automatic updates in Info.plist..."
/usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUEnableAutomaticChecks" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool false" "$INFO_PLIST" 2>/dev/null || true

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
