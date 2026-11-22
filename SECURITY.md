# Security policy

## Reporting a vulnerability

Please report security problems privately through GitHub:
**Security → Report a vulnerability** on this repository
(<https://github.com/a-magdy/openmohaa-server-kit/security/advisories/new>).
Do not open a public issue for them.

Include what you found, how to reproduce it, and which kit version or commit
you used. You should get a first answer within a week. This is a hobby project
maintained in spare time, so fixes are best effort.

## Scope

In scope: anything this repository ships, such as the image, `entrypoint.sh`
(settings validation and config rendering), `compose.yaml` hardening, the
scripts in `scripts/` and `rcon/`, and the GitHub Actions workflows.

Out of scope, please report upstream instead:

- bugs in the OpenMoHAA engine or dedicated server:
  <https://github.com/openmoh/openmohaa>
- the original game, GameSpy master servers or community maps and mods.

## Supported versions

Only the latest release gets fixes. Pin `KIT_VERSION` to a release and update
when a new one is out.

## Running a server safely

- Use a long random `RCON_PASSWORD` (`openssl rand -base64 18`) or leave it
  empty. RCON travels in plain text over UDP on the game port.
- Keep `.env`, `rcon/.env` and your game files out of git and out of images.
- Open only the two UDP ports the server needs.
