# Server side, run by ssh-run.sh after common.sh: stop the server and remove
# what Init and Deploy created. Does not delete the VPS, Docker, or the
# docker group membership.
#
#   KEEP_GAME_FILES=true   keep ~/<INSTALL_DIR>/game/ so a later Init and
#                          Deploy need no new upload
# shellcheck shell=bash

KEEP_GAME_FILES="${KEEP_GAME_FILES:-false}"

if [[ ! -d "$INSTALL_DIR" ]]; then
  log "$HOME/$INSTALL_DIR does not exist; nothing to remove."
  exit 0
fi
# Only ever remove a folder Init created.
[[ -f "$INSTALL_DIR/$MARKER" ]] ||
  die "$HOME/$INSTALL_DIR has no $MARKER file, so it was not created by Init. Refusing to remove it."

if [[ -f "$INSTALL_DIR/compose.yaml" ]]; then
  log "Stopping the server and removing its container, volume and image..."
  (cd "$INSTALL_DIR" && docker_cmd compose down --volumes --remove-orphans --rmi all)
fi

if [[ "$KEEP_GAME_FILES" == true ]]; then
  find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 ! -name game ! -name "$MARKER" -exec rm -rf -- {} +
  log "Removed everything in $HOME/$INSTALL_DIR except game/."
else
  rm -rf -- "$INSTALL_DIR"
  log "Removed $HOME/$INSTALL_DIR."
fi
log "Destroy done. The VPS itself still exists; delete it at your provider if you no longer need it."
