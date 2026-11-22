# Shared helpers for deploy/remote/*.sh. Not run on its own: ssh-run.sh
# sends it ahead of each remote script (see the workflows).
# shellcheck shell=bash

set -euo pipefail

# shellcheck disable=SC2034 # used by the scripts appended after this one
readonly MARKER=".managed-by-openmohaa-server-kit"

log() { printf '[server] %s\n' "$*"; }
die() {
  printf '[server] ERROR: %s\n' "$*" >&2
  exit 1
}

: "${INSTALL_DIR:?INSTALL_DIR is not set}"
cd "$HOME" || die "Cannot enter the home directory of $(id -un)"

# Root runs commands directly; anyone else needs passwordless sudo for the
# few steps that change the system.
as_root() {
  if (($(id -u) == 0)); then
    "$@"
  elif sudo -n true 2>/dev/null; then
    sudo -n "$@"
  else
    die "This step needs root. Log in as root or give $(id -un) passwordless sudo."
  fi
}

# Prefer the docker group; fall back to sudo right after Init added the user.
docker_cmd() {
  if docker info >/dev/null 2>&1; then
    docker "$@"
  else
    as_root docker "$@"
  fi
}
