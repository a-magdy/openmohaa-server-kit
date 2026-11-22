# Hosting on a VPS

Works on any Linux VPS or home server with Docker: Hetzner, DigitalOcean,
OVH, a Raspberry Pi 4/5 with a 64-bit OS (arm64), and so on.

This page sets it up by hand. To have GitHub Actions do Docker, the folder
and every deploy for you, see [github-actions.md](github-actions.md).

## Size

One server with up to ~30 players and bots runs comfortably on 1 vCPU and
1 GB RAM. Pick a region close to your players; ping matters more than CPU.

## 1. Install Docker

On Debian or Ubuntu, follow Docker's own guide:
<https://docs.docker.com/engine/install/>. Then check:

```bash
docker compose version
```

## 2. Open the ports

The game uses UDP only:

| Port | Purpose |
|---|---|
| `12203/udp` | Game traffic (`GAME_PORT`) |
| `12300/udp` | GameSpy server browser queries (`GAMESPY_PORT`) |

Open both in your provider's firewall or security group, and on the host if it
runs one:

```bash
sudo ufw allow 12203/udp
sudo ufw allow 12300/udp
```

Docker publishes ports past `ufw` rules on its own, so the provider firewall is
the one that counts. RCON uses the game port: anyone who can reach it can try
passwords, so use a long `RCON_PASSWORD` or leave it empty.

## 3. Get the kit on the server

```bash
git clone https://github.com/a-magdy/openmohaa-server-kit.git
cd openmohaa-server-kit
cp .env.example .env
nano .env   # hostname, RCON password, game type, maps
```

## 4. Copy your game files up

Game files come from your own copy of the game; the kit never ships them.
Prepare them on your own computer, then upload over SSH:

```bash
# on your computer, in your local clone
./scripts/prepare-game-files.sh --source ~/Downloads/setup_medal_of_honor_*.exe
./scripts/upload-game-files.sh user@your-server
```

No installer on disk? `./scripts/fetch-game-files.sh --login` (once) and then
`./scripts/fetch-game-files.sh` download your own purchase from your GOG
account with [lgogdownloader](https://github.com/Sude-/lgogdownloader) and run
the prepare step for you.

This copies `./game/` (and `./custom/`, if you use it) to
`~/openmohaa-server-kit/` on the server. Pass a second argument to use another
folder.

## 5. Start

```bash
docker compose up -d
docker compose logs -f   # Ctrl+C to stop following
```

The first start downloads the pinned OpenMoHAA release (~16 MB) into the
`data` volume. Check it from anywhere:

```bash
python3 rcon/rcon-status.py <server-ip>
```

## Updating

```bash
git pull
docker compose pull     # or: docker compose build
docker compose up -d
```

Pin `KIT_VERSION` in `.env` to a release (for example `0.1.0`) if you don't
want updates until you choose them.

## Don't

- Don't put game files in a Docker image, a public registry, a public bucket or
  a git repository. They are commercial content.
- Don't expose the server with `RCON_PASSWORD=changeme`; the kit refuses to
  start with it anyway.
