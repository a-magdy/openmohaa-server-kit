# Reusable deploy workflows

The kit ships three reusable GitHub Actions workflows that run a server on
any Linux host you can reach over SSH. Your own repository holds the
settings and three short caller workflows; the kit does the SSH work and
runs its image at a pinned version.

How to use them: [hosting/github-actions.md](../hosting/github-actions.md).
This page is the reference: the interface, what runs where, and the
security properties.

| Path | Runs on |
|---|---|
| `.github/workflows/server-{init,deploy,destroy}.yml` | GitHub (reusable, `workflow_call`) |
| `deploy/ssh-setup.sh`, `deploy/ssh-run.sh`, `deploy/server-env.sh` | the Actions runner |
| `deploy/remote/{common,init,deploy,destroy}.sh` | your server, over SSH |

## How it fits together

```
your repo (caller)                    kit repo @ vX.Y.Z (reusable)
.github/workflows/deploy.yml  ──uses──▶ .github/workflows/server-deploy.yml
  with: environment: production          job environment: production
  (passes no secrets)                     ├─ checkout caller  → site/
                                          ├─ checkout kit@vX.Y.Z → kit/ (compose.yaml, deploy/)
                                          ├─ deploy/ssh-setup.sh   (secrets via step env)
                                          └─ deploy/ssh-run.sh deploy/remote/*.sh → server
```

- **Secrets never pass through the caller.** Each reusable job sets
  `environment: ${{ inputs.environment }}`, so `secrets.X` resolves to the
  caller repository's Environment secrets and that environment's protection
  rules (required reviewers, branch limits) apply. This is also the only way
  that works across owners: `secrets: inherit` is limited to the same
  organisation. The `secrets:` blocks below are declared `required: false`
  for documentation and linting only; callers leave them out.
- **One version.** Each workflow sets `env.KIT_VERSION` to its own release
  tag without the `v`. It checks out `compose.yaml` and `deploy/` from that
  tag and writes `KIT_VERSION` into the server's `.env`, so the image is
  `ghcr.io/a-magdy/openmohaa-server-kit:<KIT_VERSION>`. A caller bumps one
  `uses:` ref (Dependabot does it) and gets matching workflows, scripts,
  compose file and image.
- **Server layout** (`install_dir`, default `openmohaa-server-kit`, relative
  to the SSH user's home; the same default as `scripts/upload-game-files.sh`):

  ```
  ~/openmohaa-server-kit/
    .managed-by-openmohaa-server-kit   written by init; destroy refuses without it
    compose.yaml                       kit compose.yaml at KIT_VERSION
    .env                               mode 600: server.env + KIT_VERSION + GAME_DIR + secrets
    game/main/pak*.pk3                 uploaded by the hoster, never by CI
    custom/custom.cfg                  from the caller repo (removed if the repo has none)
    custom/*.pk3                       copied by hand; deploy leaves them alone
  ```

## Interface

All three run on `ubuntu-24.04`, need `permissions: contents: read` only,
and share the concurrency group `openmohaa-server-<environment>` (queued,
never cancelled).

### `server-init.yml`

Prepares an existing host. Idempotent.

| Input | Type | Default | Meaning |
|---|---|---|---|
| `environment` | string | `production` | GitHub Environment holding the secrets. |
| `install_dir` | string | `openmohaa-server-kit` | Folder under the SSH user's home. |
| `server_env` | string | `server.env` | Caller settings file; read for `GAME_PORT`, `GAMESPY_PORT`. |

Secrets: `SSH_HOST`, `SSH_USER`, `SSH_PRIVATE_KEY`, `SSH_KNOWN_HOSTS`,
`SSH_PORT` (optional). Outputs: none.

Steps on the server: install Docker Engine and the Compose plugin from
Docker's apt repository if missing (Debian and Ubuntu; other distributions
fail with instructions), add the SSH user to `docker`, create
`<install_dir>/{game/main,custom}` and the marker, `ufw allow` both UDP ports
if `ufw` is active. Needs root or passwordless `sudo`.

### `server-deploy.yml`

| Input | Type | Default | Meaning |
|---|---|---|---|
| `environment` | string | `production` | GitHub Environment holding the secrets. |
| `install_dir` | string | `openmohaa-server-kit` | Folder under the SSH user's home. |
| `server_env` | string | `server.env` | Caller's non-secret settings file. |
| `custom_dir` | string | `custom` | Caller folder holding an optional `custom.cfg`. |

Secrets: the SSH set above plus `RCON_PASSWORD` (empty disables RCON) and
`SERVER_PASSWORD` (optional).

| Output | Meaning |
|---|---|
| `kit_version` | Kit version deployed, e.g. `0.2.0`. |

Order: validate `server.env` (known keys only, no secrets, no quotes,
semicolons, backslashes or `$`) → SSH login with a pinned host key → fail
unless init ran, Compose works and `game/main/pak0.pk3` exists → render
`.env` on the runner (umask 077) → upload `compose.yaml`, `.env`,
`custom.cfg` as a tar stream into a private staging folder → move into place
→ `docker compose pull` → `up -d --no-build --remove-orphans --force-recreate`
→ wait up to 300 s for the container healthcheck, printing the last 60 log
lines on failure.

### `server-destroy.yml`

| Input | Type | Default | Meaning |
|---|---|---|---|
| `environment` | string | `production` | GitHub Environment holding the secrets. |
| `install_dir` | string | `openmohaa-server-kit` | Folder under the SSH user's home. |
| `confirm` | string | required | Must be exactly `destroy`. |
| `keep_game_files` | boolean | `false` | Keep `<install_dir>/game/`. |

Secrets: the SSH set. Outputs: none. Runs `docker compose down --volumes
--remove-orphans --rmi all`, then removes the folder (or everything but
`game/`). Refuses a folder without the init marker. Never touches the VPS,
Docker itself or group membership.

## Security properties

- Secrets enter steps only via step-level `env:`; no job- or workflow-level
  env holds a secret, no `${{ }}` expression appears inside a `run:` script,
  and no secret is ever a workflow input or a command-line argument (the SSH
  host and user live in a generated `ssh_config`; `.env` travels over stdin).
- `StrictHostKeyChecking yes` with the hoster's `SSH_KNOWN_HOSTS`; no
  `ssh-keyscan` at run time.
- `server.env` is parsed, never sourced. Values forwarded to remote scripts
  (`INSTALL_DIR`, ports, `KEEP_GAME_FILES`) are validated and shell-quoted.
- Remote scripts are copied to a `mktemp` file and run with stdin closed, so
  `apt-get` or `docker` cannot swallow the script.
- Actions pinned by commit SHA; `persist-credentials: false` on checkouts.
- Keys and rendered files are deleted from the runner in an `if: always()`
  step.

## Settings file rules

`server.env` is parsed line by line, never sourced:

- Only `KEY=value` lines with keys from the kit's `.env.example` (minus the
  secrets, `KIT_VERSION` and `GAME_DIR`, which the workflow sets).
- The value is everything after the first `=`, trailing spaces trimmed. A
  `#` inside a value is kept (`SERVER_HOSTNAME=Clan #1 server`), so put
  comments on their own line.
- No quotes, semicolons, backslashes or `$` in values.
- Values are written single-quoted into the server's `.env`, so Compose
  neither cuts them at ` #` nor expands anything in them.

## Releasing

`KIT_VERSION` in the three workflows must equal the release tag without the
`v`. `scripts/release-version.sh set X.Y.Z` writes it; pre-commit checks the
three agree, and the Image workflow refuses to publish a tag that doesn't
match. See [CONTRIBUTING.md](../CONTRIBUTING.md#releasing).
