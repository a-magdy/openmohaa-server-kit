#!/usr/bin/env bash
# Runner side: run one of the deploy/remote/*.sh scripts on the target server.
#
# Usage:
#   deploy/ssh-run.sh <remote-script> [arg...]
#   deploy/ssh-run.sh --upload <local-dir>
#
# --upload copies the contents of <local-dir> into <INSTALL_DIR>/.incoming/
# on the server (created by `remote/deploy.sh stage`) as a tar stream.
#
# deploy/remote/common.sh is prepended, so remote scripts can use its helpers.
# Only these variables are forwarded, after validation: INSTALL_DIR,
# GAME_PORT, GAMESPY_PORT, KEEP_GAME_FILES. Never forward secrets this way:
# they would show up in the remote process list.

set -euo pipefail

case "${1:-}" in
  -h | --help)
    sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

die() {
  printf '::error::%s\n' "$*" >&2
  exit 1
}

(($# >= 1)) || die "Usage: ssh-run.sh <remote-script> [arg...] | --upload <local-dir>"
script="$1"
shift
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
: "${KIT_SSH_CONFIG:?Run deploy/ssh-setup.sh first}"

INSTALL_DIR="${INSTALL_DIR:-openmohaa-server-kit}"
# Relative to the SSH user's home, no '..', no leading '/' or '-'.
[[ "$INSTALL_DIR" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*(/[A-Za-z0-9_][A-Za-z0-9._-]*)*$ &&
  "$INSTALL_DIR" != *..* ]] ||
  die "install_dir must be a relative path like openmohaa-server-kit (letters, digits, . _ - /)."

if [[ "$script" == --upload ]]; then
  if (($# != 1)) || [[ ! -d "$1" ]]; then
    die "Usage: ssh-run.sh --upload <local-dir>"
  fi
  printf -v dest '%q' "$INSTALL_DIR/.incoming"
  tar -C "$1" -cf - . |
    ssh -F "$KIT_SSH_CONFIG" openmohaa-target "test -d $dest && tar -xf - -C $dest"
  exit 0
fi
[[ -f "$script" ]] || die "No such script: $script"

forward=("INSTALL_DIR=$INSTALL_DIR")
for name in GAME_PORT GAMESPY_PORT; do
  value="${!name:-}"
  [[ -z "$value" ]] && continue
  [[ "$value" =~ ^[0-9]{1,5}$ ]] || die "$name must be a port number."
  forward+=("$name=$value")
done
if [[ -n "${KEEP_GAME_FILES:-}" ]]; then
  [[ "$KEEP_GAME_FILES" == true || "$KEEP_GAME_FILES" == false ]] ||
    die "KEEP_GAME_FILES must be true or false."
  forward+=("KEEP_GAME_FILES=$KEEP_GAME_FILES")
fi
for arg in "$@"; do
  [[ "$arg" =~ ^[a-z-]+$ ]] || die "Unexpected argument: $arg"
done

# Copy common.sh plus the script to a remote temp file first, then run it:
# with `bash -s`, commands inside (apt-get, docker) could eat the script
# from stdin.
printf -v fwd '%q ' env "${forward[@]}"
args=""
(($# == 0)) || printf -v args ' %q' "$@"
remote_cmd="t=\$(mktemp) && cat >\"\$t\" && { ${fwd}bash \"\$t\"${args} </dev/null; rc=\$?; rm -f \"\$t\"; exit \$rc; }"
cat "$here/remote/common.sh" "$script" |
  ssh -F "$KIT_SSH_CONFIG" openmohaa-target "$remote_cmd"
