#!/usr/bin/env bash
# validate-pk3.sh
# Validates a downloaded .pk3 file against an expected SHA256 checksum.
# Usage: ./validate-pk3.sh <url> <expected_sha256>
# Example:
#   ./validate-pk3.sh https://yourdomain.com/mohaa/mp_snipervalley.pk3 d2f3...abcd

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <pk3_url> <expected_sha256>"
  exit 1
fi

URL="$1"
EXPECTED="$2"
TMPDIR="$(mktemp -d)"
TMPFILE="$TMPDIR/download.pk3"

trap 'rm -rf "$TMPDIR"' EXIT

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
