# openmohaa-server-kit

**Medal of Honor: Allied Assault dedicated server in Docker, powered by OpenMoHAA.**

Host an [OpenMoHAA](https://github.com/openmoh/openmohaa) dedicated server for
Medal of Honor: Allied Assault (and Spearhead / Breakthrough) with Docker
Compose. All settings live in one `.env` file.

- Runs on any Linux box or VPS with Docker (amd64 or arm64).
- Downloads the pinned OpenMoHAA release at first start and checks its sha256.
- Runs as a non-root user with your game files mounted read-only.
- Checks your settings before starting and says clearly what's wrong.

> **You must own the game.** This kit contains no game data and never downloads
> it. Buy *Medal of Honor: Allied Assault War Chest* on
> [GOG](https://www.gog.com/en/game/medal_of_honor_allied_assault_war_chest)
> and use your own copy.

Not affiliated with Electronic Arts or the OpenMoHAA project. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Why this kit

[OpenMoHAA](https://github.com/openmoh/openmohaa) is the engine; this repo is
only the packaging around its dedicated server. Compared with building the
upstream container yourself, the kit:

- runs a **pinned, sha256-checked OpenMoHAA release** instead of building
  whatever is on `main`, and a weekly workflow proposes version bumps;
- keeps **game data out of the image**: your own files are mounted read-only,
  so the image can be published and shared ([ghcr.io](https://github.com/a-magdy/openmohaa-server-kit/pkgs/container/openmohaa-server-kit), amd64 and arm64);
- puts every common setting in **one `.env` file** and refuses to start with
  unsafe or invalid values (weak RCON password, cfg injection, bad map names);
- runs **hardened**: non-root, read-only root filesystem, all capabilities
  dropped, a UDP healthcheck;
- adds helpers to **prepare game files from the GOG installer**, upload them to
  a VPS, and query or control the server over RCON.

Engine bugs and gameplay features belong upstream, not here.

## Quickstart

You need Docker with Compose, and your GOG installer or an installed copy of
the game.

```bash
git clone https://github.com/a-magdy/openmohaa-server-kit.git
cd openmohaa-server-kit

cp .env.example .env        # set SERVER_HOSTNAME, RCON_PASSWORD, maps...

# Copy pak*.pk3 from your own copy into ./game/main (and mainta/, maintt/)
./scripts/prepare-game-files.sh --source ~/Downloads/setup_medal_of_honor_allied_assault_war_chest.exe
#   or: --source "/path/to/installed/Medal of Honor Allied Assault"

docker compose up -d
python3 rcon/rcon-status.py 127.0.0.1
```

Players join with `connect <your-ip>:12203` in the console, or through the
in-game server browser when `PUBLIC_LISTING=1`.

Hosting on a VPS? Prepare the game files on your computer, then follow
[hosting/vps.md](hosting/vps.md); `./scripts/upload-game-files.sh user@host`
copies them up over SSH.

## Settings

Edit `.env`, then `docker compose up -d` to apply.

| Variable | Default | Sets |
|---|---|---|
| `SERVER_HOSTNAME` | `OpenMoHAA Server` | `sv_hostname` |
| `RCON_PASSWORD` | empty (RCON off) | `rconpassword`; at least 8 characters, no spaces, not `changeme` |
| `SERVER_PASSWORD` | empty | `g_password` (join password) |
| `GAME_TYPE` | `1` | `g_gametype`: 1 FFA, 2 Team, 3 Round, 4 Objective, 5 Tug-of-War, 6 Liberation |
| `MAP_ROTATION` | `dm/mohdm1` … `dm/mohdm7` | `sv_maplist` |
| `START_MAP` | first map in rotation | `map` (always the last line of the config) |
| `TIME_LIMIT` / `FRAG_LIMIT` / `ROUND_LIMIT` | `10` / `100` / `0` | `timelimit` / `fraglimit` / `roundlimit` |
| `TEAM_DAMAGE` | `0` | `g_teamdamage` |
| `MAX_CLIENTS` / `MAX_BOTS` | `24` / `40` | `sv_maxclients` / `sv_maxbots` (sum ≤ 64) |
| `BOT_FILL_MIN_PLAYERS` / `BOT_COUNT` | `0` / `0` | `sv_minPlayers` / `sv_numbots` |
| `PUBLIC_LISTING` | `1` | `sv_gamespy` (in-game server browser) |
| `DOWNLOAD_URL` | empty | `sv_allowDownload` + `sv_dlURL` for custom map downloads |
| `GAME_TARGET` | `0` | `com_target_game`: 0 Allied Assault, 1 Spearhead, 2 Breakthrough |
| `GAME_PORT` / `GAMESPY_PORT` | `12203` / `12300` | UDP ports, `net_port` / `net_gamespy_port` |
| `GAME_DIR` | `./game` | Host folder with your game data |
| `KIT_VERSION` | `latest` | Image tag to run |
| `MEM_LIMIT` / `CPU_LIMIT` | `1g` / `2` | Container memory and CPU limits |

Anything else goes in `custom/custom.cfg`; start from
[custom/custom.cfg.example](custom/custom.cfg.example). Values in `.env` must
not contain `"`, `;` or line breaks.

The server config is rendered at each start in this order: base config →
`.env` settings → `custom.cfg` → map rotation → start map.

## Custom maps and bots

Drop `.pk3` files into `custom/` and add their map names to `MAP_ROTATION`. See
[custom/README.md](custom/README.md) for where to find maps and how to check a
`.pk3`.

## Layout

| Path | What |
|---|---|
| `compose.yaml` | The service: ports, read-only mounts, hardening |
| `.env.example` | Every setting, documented |
| `docker/` | `Dockerfile`, `entrypoint.sh` (validate, download, render, run), `healthcheck.sh` |
| `config/` | Base server config and helper cfgs (`bots.cfg`, `help.cfg`) |
| `custom/` | Your `custom.cfg` and extra `.pk3` files (git-ignored) |
| `scripts/` | `prepare-game-files.sh`, `upload-game-files.sh`, `validate-pk3.sh` |
| `rcon/` | Python RCON and status tools, no dependencies |
| `hosting/vps.md` | Running on a VPS |
| `docs/faq/` | Paths, troubleshooting, map downloads |
| `site/` | Static guide site for GitHub Pages (`.github/workflows/pages.yml`) |

## Building the image yourself

```bash
docker compose build
```

The OpenMoHAA version and its sha256 values are build arguments in
[docker/Dockerfile](docker/Dockerfile).

## Contributing and security

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).
Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## Licence

MIT, see [LICENSE](LICENSE). OpenMoHAA (GPL-2.0) is downloaded at runtime and
not included; game data is never included.
