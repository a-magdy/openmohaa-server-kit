#!/usr/bin/env bash
# Copy the game data a dedicated server needs (pak*.pk3) from your own copy of
# Medal of Honor: Allied Assault into ./game, ready to mount at /game.
#
# Usage:
#   ./scripts/prepare-game-files.sh --source <path> [--output <dir>] [--force]
#
#   --source   One of:
#                - an installed game folder (contains main/pak0.pk3)
#                - the GOG offline installer setup_medal_of_honor_*.exe
#                  (or the folder holding it and its .bin parts)
#                - a .zip of an installed game folder
#   --output   Where to write the files (default: ./game)
#   --force    Replace an existing output folder
#
# Installer extraction uses innoextract, from your PATH or, if missing, inside
# a throwaway debian container. Only pak*.pk3 from main/, mainta/ (Spearhead)
# and maintt/ (Breakthrough) are copied; music, video and binaries are not.

set -euo pipefail

log() { printf '[prepare] %s\n' "$*"; }
die() {
  printf '[prepare] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source_path=""
output_dir="$REPO_ROOT/game"
force=0

while (($# > 0)); do
  case "$1" in
    --source)
      (($# >= 2)) || die "Missing value for --source"
      source_path="$2"
      shift 2
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
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Unknown argument: $1 (try --help)" ;;
  esac
done

[[ -n "$source_path" ]] || die "--source is required (try --help)"
[[ -e "$source_path" ]] || die "Source does not exist: $source_path"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/kit-prepare.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

find_game_root() {
  local pak
  pak="$(find "$1" -maxdepth 5 -type f -ipath '*/main/pak0.pk3' -print | sort | head -n 1)"
  [[ -n "$pak" ]] || return 1
  dirname -- "$(dirname -- "$pak")"
}

extract_installer() {
  local installer="$1" out="$2" dir name
  dir="$(cd -- "$(dirname -- "$installer")" && pwd)"
  name="$(basename -- "$installer")"
  mkdir -p "$out"
  if command -v innoextract >/dev/null 2>&1; then
    log "Extracting $name with innoextract..."
    (cd -- "$dir" && innoextract --gog --silent -d "$out" "$name") ||
      die "innoextract failed. Multi-part installers need their .bin files next to the .exe."
  elif command -v docker >/dev/null 2>&1; then
    log "innoextract not found; extracting $name inside a debian container..."
    docker run --rm \
      -u "$(id -u):$(id -g)" \
      -e INSTALLER="$name" \
      -v "$dir":/in:ro \
      -v "$out":/out \
      -w /in \
      debian:bookworm-slim \
      sh -c 'apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq innoextract >/dev/null 2>&1; innoextract --gog --silent -d /out "$INSTALLER"' ||
      die "Extraction in docker failed. Install innoextract (brew/apt install innoextract) and retry."
  else
    die "Extracting the installer needs innoextract or docker."
  fi
}

game_root=""
if [[ -d "$source_path" ]]; then
  if ! game_root="$(find_game_root "$source_path")"; then
    installer="$(find "$source_path" -maxdepth 1 -type f -iname 'setup_medal_of_honor*.exe' -print | sort | head -n 1)"
    [[ -n "$installer" ]] || die "No main/pak0.pk3 or GOG installer found in $source_path"
    extract_installer "$installer" "$work_dir/extract"
    game_root="$(find_game_root "$work_dir/extract")" || die "The installer did not contain main/pak0.pk3"
  fi
else
  case "$source_path" in
    *.exe | *.EXE)
      extract_installer "$source_path" "$work_dir/extract"
      game_root="$(find_game_root "$work_dir/extract")" || die "The installer did not contain main/pak0.pk3"
      ;;
    *.zip | *.ZIP)
      command -v unzip >/dev/null 2>&1 || die "unzip is required for .zip sources"
      unzip -q "$source_path" -d "$work_dir/extract" || die "Could not unzip $source_path"
      game_root="$(find_game_root "$work_dir/extract")" || die "The zip did not contain main/pak0.pk3"
      ;;
    *) die "Unsupported source: $source_path (expected a folder, a GOG .exe or a .zip)" ;;
  esac
fi
log "Found game data in $game_root"

if [[ -d "$output_dir" && -n "$(ls -A "$output_dir")" ]]; then
  ((force)) || die "$output_dir is not empty; pass --force to replace it"
  # Only replace something that looks like an earlier output of this script.
  [[ -d "$output_dir/main" ]] || die "$output_dir has no main/ folder; refusing to delete it"
  rm -rf "$output_dir"
fi
mkdir -p "$output_dir"
output_dir="$(cd -- "$output_dir" && pwd)"

copy_paks() {
  local sub="$1" required="$2" src count=0 pak name
  src="$(find "$game_root" -mindepth 1 -maxdepth 1 -type d -iname "$sub" -print -quit)"
  if [[ -z "$src" ]]; then
    [[ "$required" == "yes" ]] && die "Missing $sub/ in $game_root"
    return 0
  fi
  mkdir -p "$output_dir/$sub"
  while IFS= read -r -d '' pak; do
    # The server looks for lowercase names on Linux.
    name="$(basename -- "$pak" | tr '[:upper:]' '[:lower:]')"
    cp "$pak" "$output_dir/$sub/$name"
    count=$((count + 1))
  done < <(find "$src" -maxdepth 1 -type f -iname 'pak*.pk3' -print0)
  if ((count == 0)); then
    rmdir "$output_dir/$sub"
    [[ "$required" == "yes" ]] && die "No pak*.pk3 in $src"
    return 0
  fi
  log "Copied $count pak file(s) to $sub/"
}

copy_paks main yes
copy_paks mainta no
copy_paks maintt no

[[ -f "$output_dir/main/pak0.pk3" ]] || die "pak0.pk3 missing after copy"
log "Done: $output_dir"
log "This is commercial game data: keep it private, never commit it or bake it into an image."
