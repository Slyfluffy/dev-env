#!/usr/bin/env bash

opensuse_package_available() {
  zypper --non-interactive se -x "$1" >/dev/null 2>&1
}

opensuse_python_package() {
  local versioned_package=$1
  local generic_package=$2

  if "$DRY_RUN" || opensuse_package_available "$versioned_package"; then
    printf '%s\n' "$versioned_package"
  elif opensuse_package_available "$generic_package"; then
    printf '%s\n' "$generic_package"
  else
    return 1
  fi
}

install_opensuse_packages() {
  local packages=(ca-certificates curl)
  local python_package

  run "${SUDO[@]}" zypper --non-interactive refresh
  if toolset_enabled general; then
    packages+=(git wget nano)
    if python_package=$(opensuse_python_package python313-pre-commit pre-commit); then
      packages+=("$python_package")
    else
      OPENSUSE_PYTHON_UV_TOOLS+=(pre-commit)
    fi
  fi
  if toolset_enabled bash; then
    packages+=(ShellCheck bats)
  fi
  if toolset_enabled python; then
    packages+=(python3)
    if python_package=$(opensuse_python_package python313-ruff python3-ruff); then
      packages+=("$python_package")
    else
      OPENSUSE_PYTHON_UV_TOOLS+=(ruff)
    fi
    if python_package=$(opensuse_python_package python313-pytest python3-pytest); then
      packages+=("$python_package")
    else
      OPENSUSE_PYTHON_UV_TOOLS+=(pytest)
    fi
    if python_package=$(opensuse_python_package python313-pytest-cov python3-pytest-cov); then
      packages+=("$python_package")
    else
      OPENSUSE_PYTHON_UV_TOOLS+=(pytest-cov)
    fi
  fi
  if toolset_enabled go || toolset_enabled containers; then
    packages+=(go)
  fi
  toolset_enabled containers && packages+=(docker)
  toolset_enabled markdown && packages+=(nodejs npm)
  if toolset_enabled ansible; then
    packages+=(ansible)
    if python_package=$(opensuse_python_package python313-ansible-lint ansible-lint); then
      packages+=("$python_package")
    else
      OPENSUSE_PYTHON_UV_TOOLS+=(ansible-lint)
    fi
  fi
  run "${SUDO[@]}" zypper --non-interactive install "${packages[@]}"

  # OpenSUSE supplies Docker through zypper; Compose is filled in upstream
  # when the distribution package does not provide the CLI plugin.
  if ! toolset_enabled containers; then
    return
  fi

  run "${SUDO[@]}" systemctl enable --now docker
  local compose_arch
  case "$ARCH" in
  amd64) compose_arch=x86_64 ;;
  arm64) compose_arch=aarch64 ;;
  esac
  if "$DRY_RUN" || ! docker compose version >/dev/null 2>&1; then
    log "installing the pinned Docker Compose plugin release"
    install_github_asset \
      docker/compose \
      "docker-compose-linux-${compose_arch}" \
      /usr/local/lib/docker/cli-plugins/docker-compose \
      "$DOCKER_COMPOSE_TAG"
  fi
}
