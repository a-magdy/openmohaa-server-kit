# Custom config, maps and mods

Everything in this folder is mounted read-only into the container at
`/custom`. Restart after changes: `docker compose restart`.

| File | Effect |
|---|---|
| `custom.cfg` | Runs after the base config and `.env` settings, before the map rotation. Start from [`custom.cfg.example`](custom.cfg.example). |
| `*.pk3` | Loaded into the server's `main/` search path (custom maps, mods). |

`custom.cfg` and `*.pk3` are git-ignored; this repo never ships third-party
content.

## Adding a custom map

1. Download the `.pk3` from the author's or an archive's page (see below).
2. Check what it contains and its map name:

   ```bash
   unzip -l mymap.pk3 | grep '\.bsp'
   # maps/dm/mymap.bsp  ->  map name is dm/mymap
   ```

   Paths must start with `maps/`, `textures/`, `sound/` and so on. If they
   start with `main/`, the archive was packed one level too deep: unzip it and
   zip the contents of `main/` again, or the server will not find the map.
3. Put the `.pk3` in this folder and add the map name to `MAP_ROTATION` in
   `.env`.
4. Players need the same `.pk3`. Either share it, or host it and set
   `DOWNLOAD_URL` (see [nginx downloads](../docs/faq/nginx-downloads.md)).

Check each map's licence or readme before hosting it for download.

## Where to find maps

Community archives (not affiliated with this project; all maps belong to their
authors):

- [Mohaaaa maps index](http://www.mohaaaa.co.uk/AAAAMOHAA/mapsindex)
- [Customapscod: Medal of Honor maps](https://www.customapscod.com/map_screen.php?game=MOH&t=3)

## Bots

OpenMoHAA has built-in bots: set `MAX_BOTS`, `BOT_COUNT` or
`BOT_FILL_MIN_PLAYERS` in `.env`, or use `rcon addbot` /
`rcon exec bots.cfg`.

For smarter bot AI, the community **Complete Bots Mod** by its original
authors is available on ModDB:

- [The Complete Bots Mod v4.0](https://www.moddb.com/mods/the-complete-bots-mod-v40)
- [Complete Bots Mod v3.1](https://www.moddb.com/mods/mohaa-bots/downloads/zxyz-complete-bots-mod-v3-1)

Follow the mod's own install notes; its `.pk3` goes in this folder.
