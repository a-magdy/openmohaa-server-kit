#!/usr/bin/env bash
# Runner side: validate the hoster's server.env and render the server's .env.
#
# Usage:
#   deploy/server-env.sh check  <server.env>
#   deploy/server-env.sh get    <server.env> <KEY> <default>
#   deploy/server-env.sh render <server.env> <out-file>
#
# render reads RCON_PASSWORD, SERVER_PASSWORD and KIT_VERSION from the
# environment (secrets via step env:), appends them to the non-secret
# settings and writes <out-file> with mode 600. It never prints values.
#
# The file is parsed, never sourced: only KEY=value lines with known keys.
# A value is everything after the first '=', with trailing spaces trimmed, so
# '#' inside a value is kept (SERVER_HOSTNAME=Clan #1 server). Comments go on
# their own line. Values are written single-quoted, which stops compose from
# cutting them at ' #' or expanding anything in them.

set -euo pipefail

case "${1:-}" in
  -h | --help)
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

die() {
  printf '::error::%s\n' "$*" >&2
  exit 1
}

# Settings the kit's entrypoint and compose.yaml read. Keep in sync with
# .env.example in the kit.
readonly ALLOWED_KEYS=" SERVER_HOSTNAME PUBLIC_LISTING GAME_TYPE MAP_ROTATION START_MAP TIME_LIMIT FRAG_LIMIT ROUND_LIMIT TEAM_DAMAGE GAME_TARGET MAX_CLIENTS MAX_BOTS BOT_FILL_MIN_PLAYERS BOT_COUNT DOWNLOAD_URL GAME_PORT GAMESPY_PORT MEM_LIMIT CPU_LIMIT "
# Set by the workflow, never by the file.
readonly SECRET_KEYS=" RCON_PASSWORD SERVER_PASSWORD "
readonly MANAGED_KEYS=" KIT_VERSION GAME_DIR "

# Values end up single-quoted in .env and inside double-quoted cfg strings,
# so the kit's own rules apply plus no single quotes (they would end the
# quoting), backslashes or '$'.
check_value() {
  local where="$1" value="$2"
  case "$value" in
    *'"'* | *"'"* | *';'* | *\\* | *'$'* | *$'\r'*)
      die "$where: value must not contain quotes, semicolons, backslashes or \$."
      ;;
  esac
}

parse() {
  local file="$1" line key value n=0
  [[ -f "$file" ]] || die "Settings file not found: $file"
  declare -gA SETTINGS=()
  declare -ga ORDER=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    n=$((n + 1))
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*(#.*)?$ ]] && continue
    [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]] ||
      die "$file:$n: expected KEY=value, got something else."
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    # Trim trailing blanks, as compose did for unquoted values.
    value="${value%"${value##*[![:blank:]]}"}"
    if [[ "$SECRET_KEYS" == *" $key "* ]]; then
      die "$file:$n: $key is a secret. Remove it from the file (and rotate it if it was ever pushed); set it as a GitHub Environment secret."
    fi
    [[ "$MANAGED_KEYS" != *" $key "* ]] ||
      die "$file:$n: $key is set by the workflow. Remove it; bump the kit version in .github/workflows/ instead."
    [[ "$ALLOWED_KEYS" == *" $key "* ]] ||
      die "$file:$n: unknown setting $key. Put other server settings in custom/custom.cfg."
    [[ -z "${SETTINGS[$key]+x}" ]] || die "$file:$n: $key is set twice."
    check_value "$file:$n" "$value"
    SETTINGS[$key]="$value"
    ORDER+=("$key")
  done <"$file"
}

cmd="${1:-}"
case "$cmd" in
  check)
    (($# == 2)) || die "Usage: server-env.sh check <server.env>"
    parse "$2"
    printf '%s: %d settings OK.\n' "$2" "${#ORDER[@]}"
    ;;
  get)
    (($# == 4)) || die "Usage: server-env.sh get <server.env> <KEY> <default>"
    parse "$2"
    value="${SETTINGS[$3]:-}"
    printf '%s\n' "${value:-$4}"
    ;;
  render)
    (($# == 3)) || die "Usage: server-env.sh render <server.env> <out-file>"
    parse "$2"
    out="$3"
    : "${KIT_VERSION:?KIT_VERSION is not set}"
    [[ "$KIT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] ||
      die "KIT_VERSION must look like 1.2.3 or 1.2.3-rc.1."
    RCON_PASSWORD="${RCON_PASSWORD:-}"
    SERVER_PASSWORD="${SERVER_PASSWORD:-}"
    for secret in RCON_PASSWORD SERVER_PASSWORD; do
      [[ "${!secret}" != *$'\n'* ]] || die "Secret $secret must be a single line."
      check_value "Secret $secret" "${!secret}"
    done
    [[ ! "$RCON_PASSWORD" =~ [[:space:]] ]] ||
      die "Secret RCON_PASSWORD must not contain spaces (the RCON protocol splits on them)."
    if [[ -z "$RCON_PASSWORD" ]]; then
      printf '::warning::RCON_PASSWORD secret is empty: remote console is disabled.\n'
    elif ((${#RCON_PASSWORD} < 12)); then
      die "Secret RCON_PASSWORD must be at least 12 characters (generate one with: openssl rand -hex 16)."
    fi
    (
      umask 077
      mkdir -p "$(dirname -- "$out")"
      {
        printf '# Written by the openmohaa-server-kit deploy workflow. Do not edit\n'
        printf '# here: change server.env or the secrets and run Deploy again.\n'
        for key in "${ORDER[@]}"; do
          printf "%s='%s'\n" "$key" "${SETTINGS[$key]}"
        done
        printf "KIT_VERSION='%s'\n" "$KIT_VERSION"
        printf "GAME_DIR='./game'\n"
        printf "RCON_PASSWORD='%s'\n" "$RCON_PASSWORD"
        printf "SERVER_PASSWORD='%s'\n" "$SERVER_PASSWORD"
      } >"$out"
    )
    printf 'Rendered .env (%d settings plus secrets).\n' "${#ORDER[@]}"
    ;;
  *)
    die "Usage: server-env.sh check|get|render ..."
    ;;
esac
