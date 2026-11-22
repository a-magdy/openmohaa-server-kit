# Server side, run by ssh-run.sh after common.sh: prepare a Linux host.
#   - install Docker Engine and the Compose plugin if missing (Debian/Ubuntu)
#   - let the SSH user run docker
#   - create <INSTALL_DIR>/{game/main,custom} and the ownership marker
#   - open GAME_PORT/GAMESPY_PORT (UDP) in ufw if ufw is active
# Safe to run again: each step checks first.
# shellcheck shell=bash

GAME_PORT="${GAME_PORT:-12203}"
GAMESPY_PORT="${GAMESPY_PORT:-12300}"

install_docker_apt() {
  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release to detect the distribution."
  # shellcheck disable=SC1091
  . /etc/os-release
  local distro="${ID:-}" codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  case "$distro" in
    debian | ubuntu) ;;
    *) die "Automatic Docker install supports Debian and Ubuntu only (found '$distro'). Install Docker Engine with the Compose plugin yourself, then run Init again." ;;
  esac
  [[ -n "$codename" ]] || die "Cannot detect the $distro release codename."

  # Docker's documented apt repository, signed by Docker's key:
  # https://docs.docker.com/engine/install/
  log "Installing Docker Engine from download.docker.com ($distro $codename)..."
  export DEBIAN_FRONTEND=noninteractive
  as_root apt-get update -q
  as_root apt-get install -y -q ca-certificates curl
  as_root install -m 0755 -d /etc/apt/keyrings
  as_root curl -fsSL --proto '=https' "https://download.docker.com/linux/$distro/gpg" -o /etc/apt/keyrings/docker.asc
  as_root chmod a+r /etc/apt/keyrings/docker.asc
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/%s %s stable\n' \
    "$(dpkg --print-architecture)" "$distro" "$codename" |
    as_root tee /etc/apt/sources.list.d/docker.list >/dev/null
  as_root apt-get update -q
  as_root apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin
  as_root systemctl enable --now docker
}

if ! command -v docker >/dev/null 2>&1; then
  install_docker_apt
elif ! docker_cmd compose version >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    log "Docker found without the Compose plugin; installing it..."
    as_root apt-get install -y -q docker-compose-plugin ||
      die "Could not install docker-compose-plugin. Install Docker Compose v2 yourself, then run Init again."
  else
    die "Docker is installed but 'docker compose' is not. Install the Compose plugin, then run Init again."
  fi
fi
log "$(docker_cmd --version)"
log "$(docker_cmd compose version)"

user="$(id -un)"
if (($(id -u) != 0)) && ! id -nG "$user" | tr ' ' '\n' | grep -qx docker; then
  # Membership in the docker group is root-equivalent on this host; the SSH
  # key for this user must be treated like a root key.
  log "Adding $user to the docker group..."
  as_root usermod -aG docker "$user"
fi

if [[ -d "$INSTALL_DIR" && ! -f "$INSTALL_DIR/$MARKER" ]] &&
  [[ -n "$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 ! -name game ! -name custom -print -quit)" ]]; then
  die "$HOME/$INSTALL_DIR exists and was not created by Init. Pick another install_dir or empty it."
fi
mkdir -p "$INSTALL_DIR/game/main" "$INSTALL_DIR/custom"
chmod 755 "$INSTALL_DIR"
touch "$INSTALL_DIR/$MARKER"
log "Folders ready: $HOME/$INSTALL_DIR/game/main and custom/"

if command -v ufw >/dev/null 2>&1 && as_root ufw status 2>/dev/null | grep -q '^Status: active'; then
  log "ufw is active; allowing UDP $GAME_PORT and $GAMESPY_PORT..."
  as_root ufw allow "$GAME_PORT/udp" comment 'OpenMoHAA game' >/dev/null
  as_root ufw allow "$GAMESPY_PORT/udp" comment 'OpenMoHAA GameSpy' >/dev/null
else
  log "ufw not active; open UDP $GAME_PORT and $GAMESPY_PORT in your provider's firewall."
fi

if [[ -f "$INSTALL_DIR/game/main/pak0.pk3" ]]; then
  log "Game files found."
else
  log "No game files yet. From your computer, in a clone of openmohaa-server-kit, run:"
  log "  ./scripts/upload-game-files.sh <user>@<host> $INSTALL_DIR"
  log "then run the Deploy workflow."
fi
log "Init done."
