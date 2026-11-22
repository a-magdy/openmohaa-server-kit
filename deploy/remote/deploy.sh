# Server side, run by ssh-run.sh after common.sh.
#
#   deploy.sh check   fail unless Init ran, Docker works and game files exist
#   deploy.sh stage   create an empty, private <INSTALL_DIR>/.incoming/
#   deploy.sh apply   move compose.yaml, .env and custom.cfg from .incoming
#                     into place, pull the pinned image, start, wait healthy
# shellcheck shell=bash

readonly INCOMING="$INSTALL_DIR/.incoming"
readonly HEALTH_TIMEOUT=300

check() {
  [[ -f "$INSTALL_DIR/$MARKER" ]] ||
    die "$HOME/$INSTALL_DIR was not prepared. Run the Init workflow first."
  docker_cmd compose version >/dev/null 2>&1 ||
    die "Docker Compose is not available. Run the Init workflow first."
  [[ -f "$INSTALL_DIR/game/main/pak0.pk3" ]] ||
    die "Game files missing: $HOME/$INSTALL_DIR/game/main/pak0.pk3 not found. From your computer, in a clone of openmohaa-server-kit, run ./scripts/prepare-game-files.sh and then ./scripts/upload-game-files.sh <user>@<host> $INSTALL_DIR"
  log "Server ready for deploy."
}

stage() {
  rm -rf "$INCOMING"
  (umask 077 && mkdir -p "$INCOMING")
}

wait_healthy() {
  local id status waited=0
  id="$(docker_cmd compose ps -q openmohaa)"
  [[ -n "$id" ]] || return 1
  while ((waited < HEALTH_TIMEOUT)); do
    status="$(docker_cmd inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$id")"
    case "$status" in
      "running healthy") return 0 ;;
      "running starting") ;;
      # Image without a healthcheck: accept it once it has stayed up a while.
      "running ") ((waited < 30)) || return 0 ;;
      *) return 1 ;;
    esac
    sleep 10
    waited=$((waited + 10))
  done
  return 1
}

apply() {
  [[ -f "$INCOMING/compose.yaml" && -f "$INCOMING/.env" ]] ||
    die "Upload incomplete: compose.yaml or .env missing from $HOME/$INCOMING."

  # Destroy with keep_game_files leaves only game/ and the marker behind.
  mkdir -p "$INSTALL_DIR/custom"
  install -m 644 "$INCOMING/compose.yaml" "$INSTALL_DIR/compose.yaml"
  install -m 600 "$INCOMING/.env" "$INSTALL_DIR/.env"
  # custom.cfg follows the repository: present there, present here.
  # Hand-copied .pk3 files in custom/ are left alone.
  if [[ -f "$INCOMING/custom.cfg" ]]; then
    install -m 644 "$INCOMING/custom.cfg" "$INSTALL_DIR/custom/custom.cfg"
  else
    rm -f "$INSTALL_DIR/custom/custom.cfg"
  fi
  rm -rf "$INCOMING"

  cd "$INSTALL_DIR" || die "Cannot enter $HOME/$INSTALL_DIR"
  log "Pulling image..."
  docker_cmd compose pull --quiet
  log "Starting server..."
  docker_cmd compose up -d --no-build --remove-orphans --force-recreate

  log "Waiting for the server to report healthy (first start downloads OpenMoHAA)..."
  if ! wait_healthy; then
    docker_cmd compose ps
    log "Last log lines:"
    docker_cmd compose logs --no-color --tail 60 openmohaa
    die "Server did not become healthy within ${HEALTH_TIMEOUT}s. See the log lines above."
  fi
  docker_cmd compose ps
  docker_cmd image prune -f >/dev/null || true
  log "Server is up."
}

case "${1:-}" in
  check) check ;;
  stage) stage ;;
  apply) apply ;;
  *) die "Usage: deploy.sh check|stage|apply" ;;
esac
