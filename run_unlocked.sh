#!/bin/bash
set -e

# 获取脚本所在目录的绝对路径
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 解锁版应用路径
APP_PATH="${DIR}/Antigravity_Unlocked.app/Contents/MacOS/Electron"
APP_RES_DIR="${DIR}/Antigravity_Unlocked.app/Contents/Resources"
BUNDLE_DYLIB="${APP_RES_DIR}/libAntigravityTun.dylib"
BUNDLE_CONFIG="${APP_RES_DIR}/proxy_config.json"

if [ ! -f "$APP_PATH" ]; then
    echo "[Error] App executable not found at: $APP_PATH"
    echo "        Please run ./robust_unlock.sh first."
    exit 1
fi

if [ ! -f "${DIR}/libAntigravityTun.dylib" ]; then
    echo "[Error] Missing ${DIR}/libAntigravityTun.dylib"
    echo "        Please run ./compile_without_xcode.sh first."
    exit 1
fi

mkdir -p "$APP_RES_DIR"
cp "${DIR}/libAntigravityTun.dylib" "$BUNDLE_DYLIB"
if [ -f "${DIR}/config.json" ]; then
    cp "${DIR}/config.json" "$BUNDLE_CONFIG"
elif [ -f "${DIR}/proxy_config.json.example" ]; then
    cp "${DIR}/proxy_config.json.example" "$BUNDLE_CONFIG"
fi

# 首次启动显式注入；后续应用内重启依赖 Info.plist 的 LSEnvironment
export DYLD_INSERT_LIBRARIES="$BUNDLE_DYLIB"
export ANTIGRAVITY_CONFIG="$BUNDLE_CONFIG"

echo "[Run] Starting Antigravity_Unlocked.app with injection..."
echo "      DYLD_INSERT_LIBRARIES: ${DYLD_INSERT_LIBRARIES}"
echo "      ANTIGRAVITY_CONFIG:    ${ANTIGRAVITY_CONFIG}"
echo "--------------------------------------------------------"

"$APP_PATH" "$@"
