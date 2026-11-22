#!/usr/bin/env bash
# Runner side: write an SSH config for the target server from secrets.
#
# Usage (from a workflow step, secrets passed through step env:):
#   deploy/ssh-setup.sh
#
# Reads:  SSH_HOST, SSH_USER, SSH_PRIVATE_KEY, SSH_KNOWN_HOSTS, SSH_PORT (optional, 22)
# Writes: $RUNNER_TEMP/kit-ssh/{id,known_hosts,config} and KIT_SSH_CONFIG to
#         $GITHUB_ENV. Later steps run `ssh -F "$KIT_SSH_CONFIG" openmohaa-target`,
#         so host and user never appear on a command line.

set -euo pipefail

case "${1:-}" in
  -h | --help)
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

die() {
  printf '::error::%s\n' "$*" >&2
  exit 1
}

: "${RUNNER_TEMP:?RUNNER_TEMP is not set (run this inside GitHub Actions)}"
: "${GITHUB_ENV:?GITHUB_ENV is not set (run this inside GitHub Actions)}"

SSH_PORT="${SSH_PORT:-22}"

[[ -n "${SSH_HOST:-}" ]] || die "Secret SSH_HOST is missing from the environment."
[[ -n "${SSH_USER:-}" ]] || die "Secret SSH_USER is missing from the environment."
[[ -n "${SSH_PRIVATE_KEY:-}" ]] || die "Secret SSH_PRIVATE_KEY is missing from the environment."
[[ -n "${SSH_KNOWN_HOSTS:-}" ]] ||
  die "Secret SSH_KNOWN_HOSTS is missing. Run 'ssh-keyscan -t ed25519 <host>' on a trusted machine and store its output."

# Strict patterns: these values end up in an ssh_config file.
[[ "$SSH_HOST" =~ ^[A-Za-z0-9.:-]+$ ]] || die "SSH_HOST must be a hostname or IP address."
[[ "$SSH_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "SSH_USER must be a plain Linux user name."
if [[ ! "$SSH_PORT" =~ ^[0-9]{1,5}$ ]] || ((SSH_PORT < 1 || SSH_PORT > 65535)); then
  die "SSH_PORT must be a port number."
fi

dir="$RUNNER_TEMP/kit-ssh"
rm -rf "$dir"
(umask 077 && mkdir -p "$dir")

(
  umask 077
  printf '%s\n' "$SSH_PRIVATE_KEY" | tr -d '\r' >"$dir/id"
  printf '%s\n' "$SSH_KNOWN_HOSTS" | tr -d '\r' >"$dir/known_hosts"
  cat >"$dir/config" <<EOF
Host openmohaa-target
  HostName $SSH_HOST
  User $SSH_USER
  Port $SSH_PORT
  IdentityFile $dir/id
  IdentitiesOnly yes
  UserKnownHostsFile $dir/known_hosts
  StrictHostKeyChecking yes
  BatchMode yes
  ConnectTimeout 20
  ServerAliveInterval 15
  LogLevel ERROR
EOF
)

ssh-keygen -y -f "$dir/id" >/dev/null 2>&1 ||
  die "SSH_PRIVATE_KEY is not a valid private key without a passphrase."

printf 'KIT_SSH_CONFIG=%s\n' "$dir/config" >>"$GITHUB_ENV"

ssh -F "$dir/config" openmohaa-target true ||
  die "Cannot log in over SSH. Check SSH_HOST, SSH_USER, SSH_PORT, the key, and that SSH_KNOWN_HOSTS matches the server."
printf 'SSH connection OK.\n'
