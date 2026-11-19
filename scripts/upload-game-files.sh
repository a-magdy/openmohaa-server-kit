#!/usr/bin/env bash
# Copy your prepared game files to a server over SSH with rsync.
#
# Usage:
#   ./scripts/upload-game-files.sh <user@host> [remote-dir]
#
#   user@host    SSH destination (anything ssh accepts, including a Host alias)
#   remote-dir   Kit checkout on the server (default: openmohaa-server-kit,
#                relative to the remote home directory)
#
# Uploads ./game/ to <remote-dir>/game/ and, if present, ./custom/ to
# <remote-dir>/custom/. Files are sent over SSH only; nothing is made public.

set -euo pipefail

log() { printf '[upload] %s\n' "$*"; }
die() {
  printf '[upload] ERROR: %s\n' "$*" >&2
  exit 1
}

case "${1:-}" in
  "" | -h | --help)
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
    [[ -n "${1:-}" ]] && exit 0
    exit 1
    ;;
esac

destination="$1"
remote_dir="${2:-openmohaa-server-kit}"

[[ "$destination" != -* ]] || die "Destination must not start with '-'"
[[ "$remote_dir" =~ ^[A-Za-z0-9._/-]+$ ]] || die "remote-dir may only contain letters, digits and . _ / -"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

[[ -f "$REPO_ROOT/game/main/pak0.pk3" ]] ||
  die "No game/main/pak0.pk3 here. Run ./scripts/prepare-game-files.sh first."
command -v rsync >/dev/null 2>&1 || die "rsync is required on this machine (and on the server)"

ssh -- "$destination" "mkdir -p '$remote_dir/game' '$remote_dir/custom'"

log "Uploading game/ to $destination:$remote_dir/game/ ..."
rsync -az --partial --progress --chmod=D755,F644 \
  -- "$REPO_ROOT/game/" "$destination:$remote_dir/game/"

if [[ -d "$REPO_ROOT/custom" ]]; then
  log "Uploading custom/ to $destination:$remote_dir/custom/ ..."
  rsync -az --progress --chmod=D755,F644 \
    --exclude README.md --exclude custom.cfg.example \
    -- "$REPO_ROOT/custom/" "$destination:$remote_dir/custom/"
fi

log "Done. On the server: cd $remote_dir && docker compose up -d"
