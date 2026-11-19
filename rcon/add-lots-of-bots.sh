#!/usr/bin/env bash

set -euo pipefail

# Sample script demonstrating rcon-bots.py with multiple addbot commands
# This script adds various bots with different names and skill levels

# Configuration
RCON_SERVER="${RCON_SERVER:-<your-server>}"
RCON_PASSWORD="${RCON_PASSWORD:-<your-rcon-password>}"
RCON_PORT="${RCON_PORT:-12203}"

# Path to the local RCON helper scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Adding bots to MOHAA server..."
echo "Server: $RCON_SERVER:$RCON_PORT"
echo "================================"

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

"$SCRIPT_DIR/rcon-bots.py" -s "$RCON_SERVER" -p "$RCON_PASSWORD" -P "$RCON_PORT" "${names[@]}"
