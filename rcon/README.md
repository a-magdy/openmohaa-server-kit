# RCON (remote console)

Manage a running server remotely: change maps, add bots, kick players.

## Prerequisites

- A running instance of OpenMohaa server
- Basic knowledge of terminal commands
- `RCON_PASSWORD` set in the kit's `.env` (empty turns RCON off)
- In your client game, enable the UI console
  - Inside the game, go to Options > Advanced > Console (check the box)
  - Or from your `omconfig.cfg` file, set `seta ui_console "1"`

## Python RCON Tools

This directory also includes Python scripts for remote server management from the command line.

### Setup

```bash
cp rcon/.env.example rcon/.env
# Edit rcon/.env with your server IP, port, and RCON password
# (this file is separate from the kit's root .env and git-ignored)
```

### Available scripts

| Script | Purpose |
|---|---|
| `rcon.py` | Send any RCON command: `python3 rcon/rcon.py -s <ip> -p <password> status` |
| `rcon-bots.py` | Add bots by name: `python3 rcon/rcon-bots.py -s <ip> -p <password> Bot1 Bot2` |
| `rcon-status.py` | Pretty-print server status: `python3 rcon/rcon-status.py <ip>` |
| `rcon-status-minimal.py` | Compact status output: `python3 rcon/rcon-status-minimal.py <ip>` |
| `add-lots-of-bots.sh` | Bash helper to batch-add bots via the Python RCON tool |

All Python scripts read defaults from `rcon/.env` when present.

## In-Game Console

1. Open the UI console in the game

   - Press the `~` key (usually located below the `Esc` key) to open the console.
   - _If the chat box appears instead, make sure you have enabled the console in the game options => advanced => check (Console)._

2. Type the following command to connect to your server:

   - `rconpassword <your_rcon_password>`

3. Now you can execute RCON commands directly in the console.
4. To send a command, use the following format:

   - `rcon <command>`

## Common Commands

```text
// ~ to open the console
// Doesn't open? Make sure the console is enabled in the game options => advanced => check (Console).

// To authenticate with the server
rconpassword <password>

// To check the connection status
rcon status

// To add a bot
rcon addbot 1 <name>

// To add multiple bots
rcon addbot 5

// To remove bots
rcon removebots 3

// To kick a player
rcon kick <player_name>

// To broadcast a message to all players
rcon say "<message>"

// To change game type (1: Free for All, 2: Team Based)
// IMP!  ==> reload the map to apply the changes <==
rcon set g_gametype <game_type>
rcon reloadmap

// Set score limit
rcon fraglimit <score_limit>

// Set time limit
rcon timelimit <time_in_minutes>

// Toggle friendly fire (0 to disable, 1 to enable)
rcon set g_teamdamage <0|1>

// Change run speed (default is 1)
rcon set sv_dmspeedmult <speed_multiplier>

// View all available commands
rcon cmdlist

// To change the map (custom maps: see ../custom/README.md)
rcon map <map_name>

// Quick list of maps:
// - `dm/mohdm1` (Southern France)
// - `dm/mohdm2` (Destroyed Village)
// - `dm/mohdm3` (Remagen)
// - `dm/mohdm4` (The Crossroads)
// - `dm/mohdm5` (Snowy Park)
// - `dm/mohdm6` (Stalingrad)
// - `dm/mohdm7` (Algiers)

// Customize weapons and features using `bitset dmflags`
// command is: rcon bitset dmflags <number> <1/0 (default 1)>
// <number> corresponds to specific flags (see below for details)
// Common flags:

// Infinite ammo
rcon bitset dmflags 14

// No Rifle
rcon bitset dmflags 22

// No Sniper
rcon bitset dmflags 23

// No SMG
rcon bitset dmflags 24

// No MG
rcon bitset dmflags 25

// No Rocket Launcher
rcon bitset dmflags 26

// No Shotgun
rcon bitset dmflags 27

// To undo any of these, just set the value to 0 instead of 1.
// Ex. Enable rocket launcher: `rcon bitset dmflags 26 0`
```

## More customization

```text
// Negate fall damage
rcon bitset dmflags 3

// Players (or bots) spawn as far away as possible from enemies
rcon bitset dmflags 9

// Footsteps sound are disabled (silent movement)
rcon bitset dmflags 17

// Disable lean movement
rcon bitset dmflags 18 0
```

## Custom presets

Define shortcuts with `set <name> "<commands>"` in `custom/custom.cfg` (see
`custom/custom.cfg.example`) and run them with `rcon vstr <name>`. The kit
also ships `bots.cfg` and `help.cfg`: `rcon exec bots.cfg`,
`rcon exec help.cfg`.

### Example: a game-mode preset

In `custom/custom.cfg`:

```cfg
set ffa_rockets "set g_gametype 1; fraglimit 150; timelimit 15; bitset dmflags 14; reloadmap"
```

Then: `rcon vstr ffa_rockets`.

## Additional Resources

```text
  rcon cmdlist // List all available commands
  rcon exec <filename.cfg> // Execute a configuration file under ./main
  # example: rcon exec bots.cfg
  rcon reloadmap // Reload the current map
  rcon in_restart // Restart the current map
  rcon game_restart // Restart the game
```

- Rcontool (Java): <https://rcontool.sourceforge.net/>
- Rcontool (SourceForge): <https://sourceforge.net/projects/rcontool/>
- Rcontools (C#): <https://www.codeproject.com/Articles/21885/Send-RCON-Commands-to-Quake-Based-Games>
