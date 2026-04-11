#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCHER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_PATH="$LAUNCHER_ROOT/dist/release.json"
LATEST_VERSION=""
DOWNLOAD_URL=""
NOTES=""

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

usage() {
  cat <<'EOF'
Usage:
  bash scripts/generate_release_feed.sh \
    --version 0.2.0 \
    --url https://example.com/Antigravity-Proxy-Launcher.dmg \
    --notes "修复若干问题" \
    [--output dist/release.json]

Fields:
  --version   Latest launcher version
  --url       Download URL for the latest release
  --notes     Release notes text (optional)
  --output    Output JSON path (optional)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      LATEST_VERSION="${2:-}"
      shift 2
      ;;
    --url)
      DOWNLOAD_URL="${2:-}"
      shift 2
      ;;
    --notes)
      NOTES="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$LATEST_VERSION" ]]; then
  echo "error: --version is required"
  exit 1
fi

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "error: --url is required"
  exit 1
fi

if [[ "$OUTPUT_PATH" != /* ]]; then
  OUTPUT_PATH="$LAUNCHER_ROOT/$OUTPUT_PATH"
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

ESCAPED_VERSION="$(json_escape "$LATEST_VERSION")"
ESCAPED_URL="$(json_escape "$DOWNLOAD_URL")"
ESCAPED_NOTES="$(json_escape "$NOTES")"

cat > "$OUTPUT_PATH" <<EOF
{
  "latestVersion": "$ESCAPED_VERSION",
  "notes": "$ESCAPED_NOTES",
  "downloadURL": "$ESCAPED_URL"
}
EOF

echo "done"
echo "release feed: $OUTPUT_PATH"
