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
  `.env.example` and the README settings table together.

Test a change with your own game files: `docker compose up -d --build`, then
`docker compose logs` and `python3 rcon/rcon-status.py 127.0.0.1`.

## Pull requests

Keep them small and focused, describe what you tested, and use
[Conventional Commits](https://www.conventionalcommits.org/) style titles
(`fix:`, `feat:`, `docs:`). By contributing you agree that your work is
licensed under the [MIT licence](LICENSE).
