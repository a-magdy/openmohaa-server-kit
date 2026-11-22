# Third-party notices

The MIT licence in [LICENSE](LICENSE) covers the scripts, configs, Dockerfile
and documentation in this repository. It does not cover anything below.

This project is **not affiliated with, endorsed by or sponsored by Electronic
Arts or the OpenMoHAA project.** "Medal of Honor" is a trademark of Electronic
Arts Inc. Other names belong to their owners.

## Game data (not included)

Medal of Honor: Allied Assault game data (`pak*.pk3` and everything else from
the game) is commercial software owned by Electronic Arts. This repository and
its container image contain **none** of it and never download it. You must own
a legitimate copy, for example from
[GOG](https://www.gog.com/en/game/medal_of_honor_allied_assault_war_chest),
and prepare the files yourself with `scripts/prepare-game-files.sh`.

## OpenMoHAA (downloaded at runtime, not included)

[OpenMoHAA](https://github.com/openmoh/openmohaa) is licensed under the GNU
General Public License v2.0. The container image does not contain it. At first
start the entrypoint downloads the official release archive from the project's
GitHub releases, checks its pinned sha256 and runs the dedicated server from
it. Source code and licence: <https://github.com/openmoh/openmohaa>.

## Base image and packages

The image is built on `debian:bookworm-slim` and installs `ca-certificates`,
`curl` and `unzip` from Debian. Their licences are in `/usr/share/doc/*/copyright`
inside the image.

## Community maps and mods (linked, not included)

[custom/README.md](custom/README.md) links to community map archives and the
Complete Bots Mod on ModDB. Those works belong to their authors and are not
part of this repository.

## Server config

`config/base/server_opm.cfg` sets standard Medal of Honor / OpenMoHAA server
cvars. The comments are written for this kit; see the
[OpenMoHAA configuration docs](https://github.com/openmoh/openmohaa/tree/main/docs)
for the authoritative reference.
