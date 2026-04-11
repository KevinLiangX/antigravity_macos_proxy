#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_SUPPORT_DIR="$HOME/Library/Application Support/AntigravityProxy"
CACHE_FILE="$APP_SUPPORT_DIR/compatibility.registry.json"
CACHE_META_FILE="$APP_SUPPORT_DIR/compatibility.registry.meta.json"
TMP_DIR="$(mktemp -d /tmp/phase6_validation.XXXXXX)"
RESULT_LOG="$ROOT_DIR/../docs/phase6_test_run.log"

cleanup() {
  if [[ -f "$TMP_DIR/cache.backup.json" ]]; then
    mv "$TMP_DIR/cache.backup.json" "$CACHE_FILE"
  else
    rm -f "$CACHE_FILE"
  fi

  if [[ -f "$TMP_DIR/cache.meta.backup.json" ]]; then
    mv "$TMP_DIR/cache.meta.backup.json" "$CACHE_META_FILE"
  else
    rm -f "$CACHE_META_FILE"
  fi

  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$APP_SUPPORT_DIR"
: > "$RESULT_LOG"

log() {
  echo "$1" | tee -a "$RESULT_LOG"
}

run_case() {
  local name="$1"
  shift
  log "\n[CASE] $name"
  if "$@" >> "$RESULT_LOG" 2>&1; then
    log "[PASS] $name"
    return 0
  fi

  log "[FAIL] $name"
  return 1
}

# Backup existing compatibility cache if present.
if [[ -f "$CACHE_FILE" ]]; then
  cp "$CACHE_FILE" "$TMP_DIR/cache.backup.json"
fi
if [[ -f "$CACHE_META_FILE" ]]; then
  cp "$CACHE_META_FILE" "$TMP_DIR/cache.meta.backup.json"
fi

PASS_COUNT=0
FAIL_COUNT=0

run_case "Build launcher" swift build && PASS_COUNT=$((PASS_COUNT+1)) || FAIL_COUNT=$((FAIL_COUNT+1))
run_case "Doctor supported path" swift run AntigravityProxyLauncher -- --doctor && PASS_COUNT=$((PASS_COUNT+1)) || FAIL_COUNT=$((FAIL_COUNT+1))
run_case "Patch and launch CLI path" swift run AntigravityProxyLauncher -- --patch-and-launch && PASS_COUNT=$((PASS_COUNT+1)) || FAIL_COUNT=$((FAIL_COUNT+1))
run_case "Verify patched result" swift run AntigravityProxyLauncher -- --verify-patched && PASS_COUNT=$((PASS_COUNT+1)) || FAIL_COUNT=$((FAIL_COUNT+1))

# Unsupported-version simulation by injecting a temporary cache registry.
cat > "$CACHE_FILE" <<'JSON'
{
  "schemaVersion": 1,
  "rules": [
    {
      "minVersion": "999.0.0",
      "maxVersion": "999.9.9",
      "bundleIdentifier": "com.google.antigravity",
      "executableRelativePath": "Contents/MacOS/Electron"
    }
  ]
}
JSON

if swift run AntigravityProxyLauncher -- --doctor >> "$RESULT_LOG" 2>&1; then
  log "\n[FAIL] Doctor unsupported path (expected non-zero)"
  FAIL_COUNT=$((FAIL_COUNT+1))
else
  log "\n[PASS] Doctor unsupported path (got non-zero as expected)"
  PASS_COUNT=$((PASS_COUNT+1))
fi

# Restore original cache before exiting test run.
cleanup
trap - EXIT

TOTAL=$((PASS_COUNT+FAIL_COUNT))
log "\n=== Phase6 Validation Summary ==="
log "Total: $TOTAL"
log "Pass : $PASS_COUNT"
log "Fail : $FAIL_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
