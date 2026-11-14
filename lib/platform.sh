#!/usr/bin/env bash
# shellcheck disable=SC2034
toolset_enabled() {
  local requested=$1 toolset
  for toolset in "${SELECTED_TOOLSETS[@]}"; do
    [[ "$toolset" == "$requested" ]] && return 0
  done
  return 1
}

detect_platform() {
  [[ -r "$OS_RELEASE_FILE" ]] || die "cannot identify the operating system"
  local os_id os_pretty_name version_codename key value
  while IFS='=' read -r key value; do
    case "$key" in
    ID) os_id=${value//\"/} ;;
    PRETTY_NAME) os_pretty_name=${value//\"/} ;;
    VERSION_CODENAME) version_codename=${value//\"/} ;;
    esac
  done <"$OS_RELEASE_FILE"

  PRETTY_NAME=${os_pretty_name:-unknown}
  VERSION_CODENAME=${version_codename:-}
  case "${os_id:-}" in
  ubuntu) DISTRO=ubuntu ;;
  opensuse-tumbleweed | opensuse-leap | opensuse) DISTRO=opensuse ;;
  *) die "unsupported distribution: ${PRETTY_NAME:-unknown}" ;;
  esac
  case "$(uname -m)" in
  x86_64) ARCH=amd64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *) die "unsupported architecture: $(uname -m)" ;;
  esac
  if ((EUID == 0)); then
    SUDO=()
  else
    command -v sudo >/dev/null 2>&1 || die "sudo is required when not running as root"
    SUDO=(sudo)
  fi
}

confirm_installation() {
  if ! "$ASSUME_YES" && ! "$DRY_RUN"; then
    local local_prompt answer
    local_prompt="Install development tools on ${PRETTY_NAME}?"
    if toolset_enabled containers && "$CONFIGURE_DOCKER_GROUP"; then
      local_prompt+=" This adds ${SUDO_USER:-${USER:-root}} to the Docker group (root-equivalent access)."
    fi
    read -r -p "${local_prompt} [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || {
      log "cancelled"
      exit 0
    }
  fi
}
