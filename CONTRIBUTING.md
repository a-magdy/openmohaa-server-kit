# Contributing

Thanks for helping. Issues, fixes and docs improvements are all welcome.

## Before you start

- **Engine bugs and new gameplay features** belong in
  [OpenMoHAA](https://github.com/openmoh/openmohaa), not here. Read their own
  contributing guide first; it has rules of its own.
- For larger changes to the kit, open an issue first so we can agree on the
  approach.
- Never commit game data (`pak*.pk3` or anything else from the game), OpenMoHAA
  binaries, community maps, or secrets. CI rejects archives, binaries and
  `.env` files.

## Development

```bash
pip install pre-commit      # or: brew install pre-commit
pre-commit install
pre-commit run --all-files  # ShellCheck, Ruff, actionlint, zizmor, file hygiene
docker compose build        # build the image locally
```

Conventions:

- Bash: `#!/usr/bin/env bash`, `set -euo pipefail`, a `--help`, ShellCheck
  clean. Host-side scripts (`scripts/`, `rcon/`) should also run on macOS.
- Python: standard library only.
- Workflows: actions pinned by full commit SHA, least-privilege `permissions`,
  no `${{ }}` expressions inside `run:` blocks.
- A new setting goes in `docker/entrypoint.sh` (with validation),
  `.env.example`, the README settings table and `ALLOWED_KEYS` in
  `deploy/server-env.sh` together.

Test a change with your own game files: `docker compose up -d --build`, then
`docker compose logs` and `python3 rcon/rcon-status.py 127.0.0.1`.

## Releasing

Releases are `vX.Y.Z` tags on `main`. The reusable `server-*.yml` workflows
pin their own version, so it has to be bumped before tagging:

```bash
./scripts/release-version.sh set 0.3.0   # edits the three server-*.yml files
git switch -c release/v0.3.0 && git commit -am "chore: release v0.3.0"
# open a PR, merge it, then tag the merge commit:
git switch main && git pull
git tag -s v0.3.0 -m v0.3.0 && git push origin v0.3.0
```

The Image workflow checks the tag matches (`release-version.sh check`) before
it publishes `ghcr.io/<owner>/openmohaa-server-kit:0.3.0`. Then write the
GitHub release notes for the tag.

## Pull requests

Keep them small and focused, describe what you tested, and use
[Conventional Commits](https://www.conventionalcommits.org/) style titles
(`fix:`, `feat:`, `docs:`). By contributing you agree that your work is
licensed under the [MIT licence](LICENSE).
