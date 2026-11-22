#!/usr/bin/env bash
# Add a batch of named bots through rcon-bots.py.
#
# Usage:
#   ./rcon/add-lots-of-bots.sh
#   RCON_SERVER=1.2.3.4 RCON_PASSWORD=... LIMIT=10 ./rcon/add-lots-of-bots.sh
#
# Server, port and password come from the environment or rcon/.env.
# LIMIT (default 20) caps how many bots are added; 0 adds all of them.
# RANDOMIZE=false keeps the list order.

set -euo pipefail

case "${1:-}" in
  -h | --help)
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

# Only pass what is set; rcon-bots.py reads the rest from rcon/.env.
rcon_args=()
[[ -n "${RCON_SERVER:-}" ]] && rcon_args+=(-s "$RCON_SERVER")
[[ -n "${RCON_PASSWORD:-}" ]] && rcon_args+=(-p "$RCON_PASSWORD")
[[ -n "${RCON_PORT:-}" ]] && rcon_args+=(-P "$RCON_PORT")

# Path to the local RCON helper scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Adding bots to MOHAA server..."

names=(
	"Maverick"
	"Ghost"
	"Reaper"
	"Shadow"
	"Viper"
	"Falcon"
	"Ranger"
	"Hunter"
	"Cobra"
	"Eagle"
	"Striker"
	"Phantom"
	"Specter"
	"Wolf"
	"Hawk"
	"Blade"
	"Raven"
	"Steel"
	"Ace"
	"Sarge"
	"Bulldog"
	"Iceman"
	"Goose"
	"Diesel"
	"Bronco"
	"Gunner"
	"Talon"
	"Bravo"
	"Nomad"
	"Patriot"
	"Torch"
	"Ironside"
	"Frostbite"
	"Crossfire"
	"Dogface"
	"Foxhole"
	"Rifleman"
	"Corporal"
	"Sergeant"
	"Captain"
	"Hammer"
	"Thunder"
	"Blitz"
	"Overlord"
	"Bastogne"
	"Foxhound"
	"Sniper"
	"Medic"
	"Scout"
	"Sapper"
	"Radioman"
	"Demo"
	"Flanker"
	"Grizzly"
	"Badger"
	"Panther"
	"Jackal"
	"Lynx"
	"Ox"
	"Bazooka"
	"Carbine"
	"Mortar"
	"Grenadier"
	"Private"
	"Major"
	"Lieutenant"
	"Commander"
)

# Shuffle names array if RANDOMIZE is set to true, and select only a set number if LIMIT is set
RANDOMIZE=${RANDOMIZE:-true}
LIMIT=${LIMIT:-20}

if [[ "$RANDOMIZE" == "true" ]]; then
	if command -v shuf >/dev/null 2>&1; then
		mapfile -t names < <(printf "%s\n" "${names[@]}" | shuf)
	else
		echo "Warning: shuf not found; keeping original bot order." >&2
	fi
fi

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
	echo "Error: LIMIT must be a non-negative integer (current: $LIMIT)" >&2
	exit 1
fi

if [[ "$LIMIT" -gt 0 ]]; then
	names=("${names[@]:0:$LIMIT}")
fi

echo "Creating (${#names[@]}) Bots, with the following names: ${names[*]}"

python3 "$SCRIPT_DIR/rcon-bots.py" ${rcon_args[@]+"${rcon_args[@]}"} "${names[@]}"
