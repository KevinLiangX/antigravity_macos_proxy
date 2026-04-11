#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "[Phase4 Smoke] Build launcher"
swift build

echo "[Phase4 Smoke] Doctor checks"
swift run AntigravityProxyLauncher -- --doctor

echo "[Phase4 Smoke] CLI patch and launch"
swift run AntigravityProxyLauncher -- --patch-and-launch

echo "[Phase4 Smoke] Verify patched app"
swift run AntigravityProxyLauncher -- --verify-patched

echo "[Phase4 Smoke] Done"
