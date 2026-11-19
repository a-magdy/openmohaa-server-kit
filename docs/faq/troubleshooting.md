# Troubleshooting

## The container exits at start

Read the log: `docker compose logs openmohaa`. The entrypoint says what is
wrong:

| Message | Fix |
|---|---|
| `pak0.pk3 not found at /game/main/pak0.pk3` | Run `./scripts/prepare-game-files.sh`, or point `GAME_DIR` in `.env` at the folder that holds `main/pak0.pk3` |
| `... setting(s) in .env are invalid` | Each invalid value is listed above this line. Values must not contain `"`, `;` or line breaks |
| `RCON_PASSWORD must not be 'changeme'` / `at least 8 characters` | Set a real password (`openssl rand -base64 18`) or leave it empty to turn RCON off |
| `GAME_TARGET=1 needs /game/mainta/pak*.pk3` | Spearhead/Breakthrough need the expansion files; prepare them from a copy that includes them |
| `/data is not writable` | You replaced the `data` volume with a bind mount: `chown -R 1000:1000` that folder |
| `sha256 mismatch` | The download was corrupted or changed upstream. Retry; if it persists, open an issue |

## Players can't see or join the server

- Open both UDP ports (`GAME_PORT`, default 12203, and `GAMESPY_PORT`,
  default 12300) in your provider's firewall and on the host (`ufw allow
  12203/udp`).
- `PUBLIC_LISTING=1` is needed for the in-game browser. Players can always join
  directly with `connect <ip>:12203` in the console.
- Check the server answers locally: `python3 rcon/rcon-status.py 127.0.0.1`.

## Settings don't apply

Settings are rendered at container start. After editing `.env` or
`custom/custom.cfg`, run `docker compose up -d` (picks up `.env` changes) or
`docker compose restart`.

## Network diagnostics

```bash
# Is the container healthy? (UDP status query every 30 s)
docker compose ps

# UDP listeners on the host
sudo ss -ulnp | grep -E ':(12203|12300)'

# Watch game traffic arrive
sudo tcpdump -n -i any udp port 12203

# From another machine
nmap -sU -p 12203,12300 <server-ip>
```
