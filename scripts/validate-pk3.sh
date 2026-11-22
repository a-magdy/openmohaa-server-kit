#!/usr/bin/env bash
# Download a .pk3 from your download URL and check it against a sha256, to
# confirm players get the same file the server loads.
#
# Usage:
#   ./scripts/validate-pk3.sh <pk3_url> <expected_sha256>
#
# Example:
#   ./scripts/validate-pk3.sh https://example.com/mohaa/mymap.pk3 d2f3...abcd

set -euo pipefail

case "${1:-}" in
  -h | --help)
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <pk3_url> <expected_sha256> (try --help)" >&2
  exit 1
fi

URL="$1"
EXPECTED="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
WORK_DIR="$(mktemp -d)"
TMPFILE="$WORK_DIR/download.pk3"

trap 'rm -rf "$WORK_DIR"' EXIT

echo "Downloading: $URL"
curl -L --fail --progress-bar "$URL" -o "$TMPFILE"

echo "Download complete. Calculating SHA256..."
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL="$(sha256sum "$TMPFILE" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL="$(shasum -a 256 "$TMPFILE" | awk '{print $1}')"
else
  echo "No SHA256 tool available (need sha256sum or shasum)."
  exit 2
fi

echo "Expected: $EXPECTED"
echo "Actual:   $ACTUAL"

if [ "$EXPECTED" = "$ACTUAL" ]; then
  echo "✅ Checksum match. File is correct."
  exit 0
else
  echo "❌ Checksum mismatch!"
  exit 3
fi
