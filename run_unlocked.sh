#!/bin/bash

# 获取脚本所在目录的绝对路径
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 动态库和配置文件路径
export DYLD_INSERT_LIBRARIES="${DIR}/libAntigravityTun.dylib"
export ANTIGRAVITY_CONFIG="${DIR}/config.json"

# 解锁版应用路径
APP_PATH="${DIR}/Antigravity_Unlocked.app/Contents/MacOS/Electron"

echo "[Run] Starting Antigravity_Unlocked.app with injection..."
echo "      DYLD_INSERT_LIBRARIES: ${DYLD_INSERT_LIBRARIES}"
echo "      ANTIGRAVITY_CONFIG:    ${ANTIGRAVITY_CONFIG}"
echo "--------------------------------------------------------"

if [ ! -f "$APP_PATH" ]; then
    echo "[Error] App executable not found at: $APP_PATH"
    echo "        Please run ./unlock_app.sh first."
    exit 1
fi

"$APP_PATH" "$@"
