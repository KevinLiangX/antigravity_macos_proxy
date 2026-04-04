#!/bin/bash
set -e

APP_NAME="Antigravity"
# macOS sandbox path for this app. If the original bundle ID differs, adjust this.
SANDBOX_DIR="$HOME/Library/Containers/Antigravity/Data/Library/Application Support/$APP_NAME"
shopt -s nullglob
# Handle spaces correctly by not quoting the glob part but quoting the rest, or just use nullglob with array expansion
POSSIBLE_SANDBOX_DIRS=(
    "$HOME/Library/Containers/"com.*."$APP_NAME/Data/Library/Application Support/$APP_NAME"
    "$HOME/Library/Containers/$APP_NAME/Data/Library/Application Support/$APP_NAME"
)

FOUND_DIR=""
for D in "${POSSIBLE_SANDBOX_DIRS[@]}"; do
    if [ -d "$D" ]; then
        FOUND_DIR="$D"
        break
    fi
done

UNSANDBOXED_DIR="$HOME/Library/Application Support/$APP_NAME"

echo "====================================="
echo "  Antigravity Data Migration Tool"
echo "====================================="

if [ -n "$FOUND_DIR" ]; then
    echo "[*] Found original Sandbox data at: $FOUND_DIR"
    
    if [ ! -d "$UNSANDBOXED_DIR" ]; then
        echo "[*] Creating target directory: $UNSANDBOXED_DIR"
        mkdir -p "$UNSANDBOXED_DIR"
    fi
    
    echo "[*] Migrating data..."
    # Use rsync to safely copy without overwriting explicitly newer files
    rsync -av --update "$FOUND_DIR/" "$UNSANDBOXED_DIR/"
    
    echo "[SUCCESS] Data successfully migrated to Unsandboxed location."
else
    echo "[-] No Sandbox data found. Either this is a fresh install or data was already migrated."
fi

# Reset TCC Permissions
echo "-------------------------------------"
echo "[*] Resetting macOS TCC (Privacy) Permissions for Antigravity..."
# TCC Reset is safe to run. It clears out old hash bindings.
# We don't necessarily know the exact bundle ID, but resetting by common knowns or app name works in some macOS versions.
tccutil reset All "Antigravity" 2>/dev/null || true
tccutil reset All "com.google.antigravity" 2>/dev/null || true
tccutil reset All "com.apple.antigravity" 2>/dev/null || true
tccutil reset All "Antigravity_Unlocked" 2>/dev/null || true
echo "[*] TCC Permissions cleared. You will be prompted to grant permissions again upon next launch."

echo "-------------------------------------"
echo "[!] IMPORTANT NOTE:"
echo "    Due to Apple Keychain restrictions, your password token could not be migrated."
echo "    You MUST log in manually the first time you run the unlocked version."
echo "    Your session will then be safely saved to your local storage."
echo "====================================="
