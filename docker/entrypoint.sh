#!/usr/bin/env bash
# Container entrypoint: validate .env settings, fetch the pinned OpenMoHAA
# release on first start, render server.cfg and exec the dedicated server.
#
# Paths:
#   /game    your game data, read-only (needs main/pak0.pk3)
#   /custom  optional custom.cfg and extra .pk3 files, read-only
#   /data    writable state: OpenMoHAA binaries cache and fs_homepath

set -euo pipefail

readonly GAME_ROOT="/game"
readonly CUSTOM_ROOT="/custom"
readonly DATA_ROOT="/data"
readonly KIT_CONFIG="/opt/kit/config"
readonly HOME_PATH="$DATA_ROOT/home"
readonly HOME_MAIN="$HOME_PATH/main"

log() { printf '[kit] %s\n' "$*"; }
warn() { printf '[kit] WARNING: %s\n' "$*" >&2; }
die() {
  printf '[kit] ERROR: %s\n' "$*" >&2
  exit 1
}

# ---------------------------------------------------------------- game data

# The engine matches pak names case-insensitively (installs ship Pak0.pk3).
has_paks() {
  [[ -n "$(find "$GAME_ROOT/$1" -maxdepth 1 -type f -iname "$2" -print -quit 2>/dev/null)" ]]
}

if ! has_paks main pak0.pk3; then
  die "pak0.pk3 not found at $GAME_ROOT/main/pak0.pk3. Mount your own game files read-only at $GAME_ROOT (see README: scripts/prepare-game-files.sh)."
fi

# ---------------------------------------------------------------- settings

SERVER_HOSTNAME="${SERVER_HOSTNAME:-OpenMoHAA Server}"
RCON_PASSWORD="${RCON_PASSWORD:-}"
SERVER_PASSWORD="${SERVER_PASSWORD:-}"
GAME_TYPE="${GAME_TYPE:-1}"
MAP_ROTATION="${MAP_ROTATION:-dm/mohdm1 dm/mohdm2 dm/mohdm3 dm/mohdm4 dm/mohdm5 dm/mohdm6 dm/mohdm7}"
START_MAP="${START_MAP:-}"
TIME_LIMIT="${TIME_LIMIT:-10}"
FRAG_LIMIT="${FRAG_LIMIT:-100}"
ROUND_LIMIT="${ROUND_LIMIT:-0}"
TEAM_DAMAGE="${TEAM_DAMAGE:-0}"
MAX_CLIENTS="${MAX_CLIENTS:-24}"
MAX_BOTS="${MAX_BOTS:-40}"
BOT_FILL_MIN_PLAYERS="${BOT_FILL_MIN_PLAYERS:-0}"
BOT_COUNT="${BOT_COUNT:-0}"
PUBLIC_LISTING="${PUBLIC_LISTING:-1}"
DOWNLOAD_URL="${DOWNLOAD_URL:-}"
GAME_TARGET="${GAME_TARGET:-0}"
GAME_PORT="${GAME_PORT:-12203}"
GAMESPY_PORT="${GAMESPY_PORT:-12300}"

# ---------------------------------------------------------------- validation

errors=0
bad() {
  printf '[kit] ERROR: %s\n' "$*" >&2
  errors=$((errors + 1))
}

# Values end up inside double-quoted cfg strings; a quote, semicolon or
# newline would end the string and let the value inject cfg commands.
check_cfg_safe() {
  local name="$1" value="${!1}"
  case "$value" in
    *'"'* | *';'* | *$'\n'* | *$'\r'*)
      bad "$name must not contain double quotes, semicolons or newlines"
      ;;
  esac
}

check_int() {
  local name="$1" min="$2" max="$3" value="${!1}"
  if [[ ! "$value" =~ ^[0-9]+$ ]] || ((10#$value < min || 10#$value > max)); then
    bad "$name must be a whole number from $min to $max (got '$value')"
  fi
}

check_map_name() {
  local name="$1" map="$2"
  if [[ ! "$map" =~ ^[A-Za-z0-9_./-]+$ || "$map" == *..* ]]; then
    bad "$name contains an invalid map name '$map' (use names like dm/mohdm1)"
  fi
}

for var in SERVER_HOSTNAME RCON_PASSWORD SERVER_PASSWORD MAP_ROTATION START_MAP DOWNLOAD_URL; do
  check_cfg_safe "$var"
done

[[ -n "$SERVER_HOSTNAME" ]] || bad "SERVER_HOSTNAME must not be empty"

if [[ -z "$RCON_PASSWORD" ]]; then
  warn "RCON_PASSWORD is empty: remote console (RCON) is disabled."
elif [[ "${RCON_PASSWORD,,}" == "changeme" ]]; then
  bad "RCON_PASSWORD must not be 'changeme'; pick a real password or leave it empty to disable RCON"
elif ((${#RCON_PASSWORD} < 8)); then
  bad "RCON_PASSWORD must be at least 8 characters (or empty to disable RCON)"
elif [[ "$RCON_PASSWORD" =~ [[:space:]] ]]; then
  bad "RCON_PASSWORD must not contain spaces (the RCON protocol splits on them)"
fi

check_int GAME_TYPE 1 6
check_int TIME_LIMIT 0 1440
check_int FRAG_LIMIT 0 100000
check_int ROUND_LIMIT 0 1440
check_int TEAM_DAMAGE 0 1
check_int MAX_CLIENTS 1 64
check_int MAX_BOTS 0 64
check_int BOT_FILL_MIN_PLAYERS 0 64
check_int BOT_COUNT 0 64
check_int PUBLIC_LISTING 0 1
check_int GAME_TARGET 0 2
check_int GAME_PORT 1024 65535
check_int GAMESPY_PORT 1024 65535

if ((errors == 0)); then
  ((MAX_CLIENTS + MAX_BOTS <= 64)) ||
    bad "MAX_CLIENTS + MAX_BOTS must be 64 or less (got $((MAX_CLIENTS + MAX_BOTS)))"
  ((BOT_COUNT <= MAX_BOTS)) || bad "BOT_COUNT ($BOT_COUNT) must not exceed MAX_BOTS ($MAX_BOTS)"
  ((BOT_FILL_MIN_PLAYERS <= MAX_CLIENTS + MAX_BOTS)) ||
    bad "BOT_FILL_MIN_PLAYERS must not exceed MAX_CLIENTS + MAX_BOTS"
  ((GAME_PORT != GAMESPY_PORT)) || bad "GAME_PORT and GAMESPY_PORT must differ"
fi

read -r -a rotation <<<"$MAP_ROTATION"
((${#rotation[@]} > 0)) || bad "MAP_ROTATION must list at least one map"
for map in "${rotation[@]}"; do
  check_map_name MAP_ROTATION "$map"
done
[[ -n "$START_MAP" ]] || START_MAP="${rotation[0]:-}"
check_map_name START_MAP "$START_MAP"

if [[ -n "$DOWNLOAD_URL" && ! "$DOWNLOAD_URL" =~ ^https?://[^[:space:]]+$ ]]; then
  bad "DOWNLOAD_URL must be an http:// or https:// URL without spaces"
fi

((errors == 0)) || die "$errors setting(s) in .env are invalid; fix them and start again."

case "$GAME_TARGET" in
  1) expansion_dir="mainta" ;;
  2) expansion_dir="maintt" ;;
  *) expansion_dir="" ;;
esac
if [[ -n "$expansion_dir" ]] && ! has_paks "$expansion_dir" 'pak*.pk3'; then
  die "GAME_TARGET=$GAME_TARGET needs $GAME_ROOT/$expansion_dir/pak*.pk3 from the expansion pack."
fi

# ---------------------------------------------------------------- binaries

case "$(uname -m)" in
  x86_64 | amd64)
    om_arch="amd64"
    om_sha256="${OPENMOHAA_SHA256_AMD64:-}"
    ;;
  aarch64 | arm64)
    om_arch="arm64"
    om_sha256="${OPENMOHAA_SHA256_ARM64:-}"
    ;;
  *) die "Unsupported CPU architecture: $(uname -m) (supported: amd64, arm64)" ;;
esac

om_version="${OPENMOHAA_VERSION:?OPENMOHAA_VERSION is not set in the image}"
[[ "$om_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "OPENMOHAA_VERSION has an unexpected format: $om_version"
[[ "$om_sha256" =~ ^[0-9a-f]{64}$ ]] || die "No valid sha256 pinned for OpenMoHAA $om_version on $om_arch"

bin_dir="$DATA_ROOT/openmohaa/$om_version-$om_arch"

install_openmohaa() {
  local asset="openmohaa-$om_version-linux-$om_arch.zip"
  local url="https://github.com/openmoh/openmohaa/releases/download/$om_version/$asset"
  local tmp
  tmp="$(mktemp -d "$DATA_ROOT/openmohaa/.download.XXXXXX")"

  log "Downloading OpenMoHAA $om_version ($om_arch) from GitHub..."
  curl -fsSL --retry 3 --proto '=https' --output "$tmp/$asset" "$url" ||
    die "Download failed: $url"
  printf '%s  %s\n' "$om_sha256" "$tmp/$asset" | sha256sum --check --status ||
    die "sha256 mismatch for $asset; refusing to run it"

  # Only the dedicated server and the modules it loads; the client is not needed.
  unzip -q "$tmp/$asset" omohaaded game.so libcurl.so.4 -d "$tmp/bin" ||
    die "Unexpected archive layout in $asset"
  chmod 0755 "$tmp/bin/omohaaded"
  rm -rf "$bin_dir"
  mv "$tmp/bin" "$bin_dir"
  rm -rf "$tmp"
  touch "$bin_dir/.complete"
  log "Installed OpenMoHAA $om_version to $bin_dir"
}

mkdir -p "$DATA_ROOT/openmohaa" || die "$DATA_ROOT is not writable by uid $(id -u)"
[[ -f "$bin_dir/.complete" ]] || install_openmohaa

# ---------------------------------------------------------------- config

mkdir -p "$HOME_MAIN"

# Reset files the kit manages, so removed custom content does not linger.
find "$HOME_MAIN" -maxdepth 1 \( -type l -name '*.pk3' -o -name custom.cfg \) -delete

cp "$KIT_CONFIG/base/default.cfg" "$HOME_MAIN/default.cfg"
cp "$KIT_CONFIG/helpers/"*.cfg "$HOME_MAIN/"

has_custom_cfg=0
if [[ -f "$CUSTOM_ROOT/custom.cfg" ]]; then
  cp "$CUSTOM_ROOT/custom.cfg" "$HOME_MAIN/custom.cfg"
  has_custom_cfg=1
  log "Using custom.cfg"
fi

shopt -s nullglob nocaseglob
for pk3 in "$CUSTOM_ROOT"/*.pk3; do
  ln -sf "$pk3" "$HOME_MAIN/$(basename -- "$pk3")"
  log "Loaded custom pk3: $(basename -- "$pk3")"
done
shopt -u nullglob nocaseglob

if [[ -n "$DOWNLOAD_URL" ]]; then
  allow_download=1
else
  allow_download=0
fi

{
  printf '// Rendered by openmohaa-server-kit at container start. Do not edit:\n'
  printf '// change .env or custom/custom.cfg and restart instead.\n\n'
  printf '// ---- 1. base: config/base/server_opm.cfg ----\n'
  cat "$KIT_CONFIG/base/server_opm.cfg"
  printf '\n// ---- 2. generated from .env ----\n'
  printf 'sv_hostname "%s"\n' "$SERVER_HOSTNAME"
  printf 'set rconpassword "%s"\n' "$RCON_PASSWORD"
  printf 'set g_password "%s"\n' "$SERVER_PASSWORD"
  printf 'set g_gametype %s\n' "$GAME_TYPE"
  printf 'timelimit %s\n' "$TIME_LIMIT"
  printf 'fraglimit %s\n' "$FRAG_LIMIT"
  printf 'roundlimit %s\n' "$ROUND_LIMIT"
  printf 'set g_teamdamage %s\n' "$TEAM_DAMAGE"
  printf 'set sv_maxclients %s\n' "$MAX_CLIENTS"
  printf 'set sv_maxbots %s\n' "$MAX_BOTS"
  printf 'set sv_minPlayers %s\n' "$BOT_FILL_MIN_PLAYERS"
  printf 'set sv_numbots %s\n' "$BOT_COUNT"
  printf 'set sv_gamespy %s\n' "$PUBLIC_LISTING"
  printf 'set sv_allowDownload %s\n' "$allow_download"
  printf 'set sv_dlURL "%s"\n' "$DOWNLOAD_URL"
  if ((has_custom_cfg)); then
    printf '\n// ---- 3. custom/custom.cfg ----\n'
    printf 'exec custom.cfg\n'
  fi
  printf '\n// ---- 4. rotation and start map (map must stay last) ----\n'
  printf 'sv_maplist "%s"\n' "${rotation[*]}"
  printf 'map "%s"\n' "$START_MAP"
} >"$HOME_MAIN/server.cfg"

log "Rendered $HOME_MAIN/server.cfg (start map: $START_MAP, game type: $GAME_TYPE)"

# ---------------------------------------------------------------- launch

if ((PUBLIC_LISTING)); then
  dedicated=2
else
  dedicated=1
fi

cd "$bin_dir"
log "Starting OpenMoHAA $om_version on udp/$GAME_PORT (GameSpy udp/$GAMESPY_PORT)"
exec ./omohaaded \
  +set dedicated "$dedicated" \
  +set fs_basepath "$GAME_ROOT" \
  +set fs_homepath "$HOME_PATH" \
  +set net_port "$GAME_PORT" \
  +set net_gamespy_port "$GAMESPY_PORT" \
  +set com_target_game "$GAME_TARGET" \
  +exec server.cfg
