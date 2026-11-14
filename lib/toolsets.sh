#!/usr/bin/env bash

configure_docker_group() {
  local docker_user=${SUDO_USER:-${USER:-root}}

  if ! "$DRY_RUN"; then
    id -u "$docker_user" >/dev/null 2>&1 ||
      die "cannot find the user to add to the Docker group: $docker_user"
  fi
  run "${SUDO[@]}" usermod -aG docker "$docker_user"
  if "$DRY_RUN"; then
    log "would add ${docker_user} to the Docker group"
  else
    log "added ${docker_user} to the Docker group; start a new session to use Docker without sudo"
  fi
}

install_markdown_tools() {
  if toolset_enabled markdown; then
    run "${SUDO[@]}" npm install --global \
      "markdownlint-cli2@${MARKDOWNLINT_CLI2_VERSION}"
  fi
}
