#!/usr/bin/env bash
# Download YOUR OWN copy of Medal of Honor: Allied Assault from your GOG
# account and turn it into ./game, ready to mount at /game.
#
# Usage:
#   ./scripts/fetch-game-files.sh --login
#   ./scripts/fetch-game-files.sh [--output <dir>] [--force] [--game <slug>]
#
#   --login    One-time sign-in. lgogdownloader prints a GOG login URL; open it
#              in a browser, then paste the final URL back. The token it keeps
#              in ~/.config/lgogdownloader is as sensitive as your GOG password.
#   --output   Where to write the files (default: ./game)
#   --force    Replace an existing output folder
#   --game     GOG product slug (default: medal_of_honor_allied_assault_war_chest)
#
# Needs lgogdownloader (brew/apt install lgogdownloader) or docker. The GOG
# account must own the game. The installer is downloaded to a temporary folder,
# handed to prepare-game-files.sh and deleted. Nothing here runs in CI: keep
# the token on a machine you control, never in a repository or a shared secret.

set -euo pipefail

log() { printf '[fetch] %s\n' "$*"; }
die() {
  printf '[fetch] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

do_login=0
output_dir="$REPO_ROOT/game"
force=0
slug="medal_of_honor_allied_assault_war_chest"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/lgogdownloader"

while (($# > 0)); do
  case "$1" in
    --login)
      do_login=1
      shift
      ;;
    --output)
      (($# >= 2)) || die "Missing value for --output"
      output_dir="$2"
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    --game)
      (($# >= 2)) || die "Missing value for --game"
      slug="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Unknown argument: $1 (try --help)" ;;
  esac
done

[[ "$slug" =~ ^[a-z0-9_]+$ ]] || die "--game may only contain a-z, 0-9 and _"

mkdir -p "$config_dir"
chmod 700 "$config_dir"
config_dir="$(cd -- "$config_dir" && pwd)"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/kit-fetch.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

# run_lgog <lgogdownloader args>
# Uses a local lgogdownloader when present, otherwise a throwaway container.
run_lgog() {
  if command -v lgogdownloader >/dev/null 2>&1; then
    lgogdownloader "$@"
    return
  fi
  command -v docker >/dev/null 2>&1 ||
    die "Needs lgogdownloader (brew/apt install lgogdownloader) or docker."
  log "lgogdownloader not found; running it in a debian container..."
  local tty=()
  [[ -t 0 && -t 1 ]] && tty=(-it)
  docker run --rm "${tty[@]}" \
    -e OWNER="$(id -u):$(id -g)" \
    -v "$config_dir":/root/.config/lgogdownloader \
    -v "$work_dir":/work \
    -w /work \
    debian:trixie-slim \
    sh -c 'apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq lgogdownloader >/dev/null 2>&1 && lgogdownloader "$@"; rc=$?; chown -R "$OWNER" /root/.config/lgogdownloader /work; exit $rc' \
    lgogdownloader "$@"
}

# Inside docker the download folder is /work/dl; locally it is $work_dir/dl.
if command -v lgogdownloader >/dev/null 2>&1; then
  dl_arg="$work_dir/dl"
else
  dl_arg="/work/dl"
fi

if ((do_login)); then
  run_lgog --login
  log "Signed in. Run this script again without --login to download."
  exit 0
fi

[[ -n "$(ls -A "$config_dir" 2>/dev/null)" ]] ||
  die "Not signed in. Run: $0 --login"

log "Downloading the installer for '$slug' from your GOG library (about 1 GB)..."
run_lgog --download --game "^${slug}\$" --platform w --language en \
  --include bi --no-subdirectories --directory "$dl_arg"

ls "$work_dir"/dl/setup_medal_of_honor*.exe >/dev/null 2>&1 ||
  die "No installer downloaded. Does this GOG account own '$slug'? Check with: lgogdownloader --list"

prepare=("$SCRIPT_DIR/prepare-game-files.sh" --source "$work_dir/dl" --output "$output_dir")
((force)) && prepare+=(--force)
"${prepare[@]}"
