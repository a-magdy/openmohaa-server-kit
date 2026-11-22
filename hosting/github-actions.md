# Deploying from GitHub Actions

Run the server on any Debian or Ubuntu VPS and manage it from your own GitHub
repository: you edit one settings file, push, and a workflow uploads it and
restarts the server. The kit's reusable workflows do the SSH work; your
repository holds only settings and three short files that call them.

Prefer to run `docker compose` by hand? See [vps.md](vps.md) instead.

You need a VPS you can reach over SSH with a key (1 vCPU and 1 GB RAM is
enough) and your own copy of the game.

## 1. Make your repository

Create a repository (private is fine) with this layout:

```
server.env                      your settings
custom/custom.cfg               optional, any other server commands
.github/workflows/init.yml
.github/workflows/deploy.yml
.github/workflows/destroy.yml
.github/dependabot.yml          optional, opens a PR for each kit release
```

**`server.env`**: copy the kit's [`.env.example`](../.env.example) and delete
`RCON_PASSWORD`, `SERVER_PASSWORD`, `GAME_DIR` and `KIT_VERSION` (the
workflow sets those). Rules: one `KEY=value` per line, comments on their own
line, no quotes, semicolons, backslashes or `$`. A `#` inside a value is fine
(`SERVER_HOSTNAME=Clan #1 server`). Anything not in that file goes in
`custom/custom.cfg`; start from
[custom/custom.cfg.example](../custom/custom.cfg.example).

**`.github/workflows/init.yml`**:

```yaml
name: Init server
on:
  workflow_dispatch:
permissions:
  contents: read
jobs:
  init:
    uses: a-magdy/openmohaa-server-kit/.github/workflows/server-init.yml@v0.2.0
    with:
      environment: production
```

**`.github/workflows/deploy.yml`**:

```yaml
name: Deploy server
on:
  push:
    branches: [main]
    paths: [server.env, custom/**, .github/workflows/deploy.yml]
  workflow_dispatch:
permissions:
  contents: read
jobs:
  deploy:
    uses: a-magdy/openmohaa-server-kit/.github/workflows/server-deploy.yml@v0.2.0
    with:
      environment: production
```

**`.github/workflows/destroy.yml`**:

```yaml
name: Destroy server
on:
  workflow_dispatch:
    inputs:
      confirm:
        description: Type destroy to confirm
        required: true
        type: string
      keep_game_files:
        description: Keep the uploaded game files on the server
        type: boolean
        default: false
permissions:
  contents: read
jobs:
  destroy:
    uses: a-magdy/openmohaa-server-kit/.github/workflows/server-destroy.yml@v0.2.0
    with:
      environment: production
      confirm: ${{ inputs.confirm }}
      keep_game_files: ${{ inputs.keep_game_files }}
```

**`.github/dependabot.yml`** (optional):

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    groups:
      openmohaa-server-kit:
        patterns: ["a-magdy/openmohaa-server-kit*"]
```

Every input, output and default is listed in
[deploy/README.md](../deploy/README.md#interface).

## 2. Open the ports

In your VPS provider's firewall, allow inbound **UDP 12203** and **UDP
12300** (and SSH). Docker publishes ports past `ufw`, so the provider
firewall is the one that counts.

## 3. Make a deploy key and pin the host key

On your computer:

```bash
ssh-keygen -t ed25519 -N '' -C openmohaa-deploy -f ./openmohaa-deploy
ssh-copy-id -i ./openmohaa-deploy.pub <user>@<host>
ssh-keyscan -t ed25519 <host> > ./known_hosts   # compare with your provider's console
```

## 4. Add the secrets

In your repository: **Settings → Environments → New environment**, name it
`production`, add yourself as a required reviewer and limit it to `main`.
Then add these as **environment secrets** (not repository secrets):

| Secret | Required | Value |
|---|---|---|
| `SSH_HOST` | yes | Server hostname or IP address |
| `SSH_USER` | yes | `root`, or a user with passwordless `sudo` (Init needs it once) |
| `SSH_PRIVATE_KEY` | yes | Contents of `openmohaa-deploy` |
| `SSH_KNOWN_HOSTS` | yes | Contents of `known_hosts` from step 3 |
| `RCON_PASSWORD` | recommended | 12+ characters, no spaces or quotes: `openssl rand -hex 16`. Empty turns RCON off |
| `SERVER_PASSWORD` | no | Join password; unset means an open server |
| `SSH_PORT` | no | If SSH is not on 22 |

Delete the local key files once they are stored. Your caller workflows pass
no secrets: the kit's jobs run inside your `production` environment, read
them there, and your required reviewers approve each run.

## 5. Init, upload game files, deploy

1. **Actions → Init server → Run workflow.** Installs Docker if missing,
   creates `~/openmohaa-server-kit/` on the server, opens the UDP ports in
   `ufw` if it is active. Safe to re-run.
2. Upload your game files once, from a clone of this kit on your computer:

   ```bash
   ./scripts/prepare-game-files.sh --source <your installer or install folder>
   ./scripts/upload-game-files.sh <user>@<host>
   ```

3. Commit `server.env` to `main`. **Deploy server** runs, waits for your
   approval, uploads the settings, starts the server and waits until it is
   healthy.

Check it with `python3 rcon/rcon-status.py <host>`.

## Updating and rolling back

Your server runs the kit version in the `uses:` lines (`@v0.2.0`): the
workflows, deploy scripts, `compose.yaml` and image tag all follow that one
tag. Dependabot opens a PR when a new release is out; merging it deploys.
To roll back, revert that commit.

For the strictest setup, pin each `uses:` to the release's full commit SHA
with the tag in a comment (`@<sha> # v0.2.0`); Dependabot updates that form
too.

## Removing the server

**Actions → Destroy server**, type `destroy`. It stops the server and removes
its container, volume, image and folder (optionally keeping the game files).
It never deletes the VPS.

## Troubleshooting

| Message | Fix |
|---|---|
| `Cannot log in over SSH` | Check `SSH_HOST`, `SSH_USER`, `SSH_PORT`, the key in `authorized_keys`, and that `SSH_KNOWN_HOSTS` is current (it changes when a VPS is rebuilt) |
| `This step needs root` | Run Init as `root`, or give the user passwordless `sudo` |
| `Game files missing` | Do step 5.2, then run Deploy again |
| `was not prepared. Run the Init workflow first` | Run **Init server** |
| `unknown setting` | Not a kit setting; put the command in `custom/custom.cfg` |
| `did not become healthy` | Read the log lines printed above it; the kit explains invalid settings there |
