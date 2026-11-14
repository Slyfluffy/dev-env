#!/usr/bin/env bash

install_ubuntu_packages() {
  local packages=(ca-certificates curl)
  if toolset_enabled general; then
    packages+=(git wget nano pre-commit)
  fi
  if toolset_enabled bash; then
    packages+=(shellcheck bats)
  fi
  toolset_enabled python && packages+=(python3)
  if toolset_enabled go || toolset_enabled containers; then
    packages+=(golang)
  fi
  toolset_enabled containers && packages+=(gnupg)
  toolset_enabled markdown && packages+=(nodejs npm)
  run "${SUDO[@]}" apt-get update
  run "${SUDO[@]}" apt-get install -y "${packages[@]}"

  # Docker's official repository provides the Engine and Compose CLI plugin.
  if ! toolset_enabled containers; then
    return
  fi

  local keyring=/etc/apt/keyrings/docker.gpg
  local key_file="$TEMP_DIR/docker.asc"
  local repository_entry
  [[ -n "$VERSION_CODENAME" ]] ||
    die "Ubuntu release does not provide VERSION_CODENAME"
  repository_entry=$(printf 'deb [arch=%s signed-by=%s] https://download.docker.com/linux/ubuntu %s stable' \
    "$ARCH" "$keyring" "$VERSION_CODENAME")
  if "$DRY_RUN"; then
    run "${SUDO[@]}" install -m 0755 -d /etc/apt/keyrings
    run curl -fsSL -o "$key_file" https://download.docker.com/linux/ubuntu/gpg
    run gpg --show-keys --with-colons "$key_file"
    run "${SUDO[@]}" gpg --dearmor --yes -o "$keyring" "$key_file"
    run "${SUDO[@]}" chmod a+r "$keyring"
    log "would write ${repository_entry} to /etc/apt/sources.list.d/docker.list"
  else
    "${SUDO[@]}" install -m 0755 -d /etc/apt/keyrings
    curl -fsSL -o "$key_file" https://download.docker.com/linux/ubuntu/gpg
    local fingerprint
    fingerprint=$(gpg --show-keys --with-colons "$key_file" |
      awk -F: '$1 == "fpr" { print $10; exit }')
    [[ "$fingerprint" == "$DOCKER_KEY_FINGERPRINT" ]] ||
      die "Docker repository key fingerprint did not match the expected value"
    "${SUDO[@]}" gpg --dearmor --yes -o "$keyring" "$key_file"
    "${SUDO[@]}" chmod a+r "$keyring"
    printf '%s\n' "$repository_entry" |
      "${SUDO[@]}" tee /etc/apt/sources.list.d/docker.list >/dev/null
  fi
  run "${SUDO[@]}" apt-get update
  run "${SUDO[@]}" apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin
  run "${SUDO[@]}" apt-get install -y docker-compose-plugin
  run "${SUDO[@]}" systemctl enable --now docker
}
