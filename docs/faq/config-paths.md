# Config paths

Inside the container:

| Path | Mode | Holds |
|---|---|---|
| `/game` | read-only | Your game data: `main/pak*.pk3`, optional `mainta/`, `maintt/`. Used as `fs_basepath`. |
| `/custom` | read-only | `custom.cfg` and extra `.pk3` files from `./custom` |
| `/data/openmohaa/<version>-<arch>/` | writable | OpenMoHAA server binaries, downloaded and checked at first start |
| `/data/home/main/` | writable | `fs_homepath`: the rendered `server.cfg`, `default.cfg`, helper cfgs, links to custom `.pk3` files, logs |

`/data` is the named Docker volume `data`. To see the rendered config:

```bash
docker compose exec openmohaa cat /data/home/main/server.cfg
```

To force a fresh OpenMoHAA download (for example after changing the pinned
version), remove the volume: `docker compose down -v`. That also clears logs.

## Load order of `server.cfg`

1. `config/base/server_opm.cfg`
2. Settings from `.env`
3. `exec custom.cfg` (only if `custom/custom.cfg` exists)
4. `sv_maplist` from `MAP_ROTATION`
5. `map` from `START_MAP`, always last so every setting is in place before the
   first map loads
