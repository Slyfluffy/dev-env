#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034

# Install selected development toolsets on supported Ubuntu and OpenSUSE hosts.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
readonly SCRIPT_DIR

# shellcheck source=lib/runtime.sh
source "${SCRIPT_DIR}/lib/runtime.sh"
# shellcheck source=lib/manifest.sh
source "${SCRIPT_DIR}/lib/manifest.sh"
# shellcheck source=lib/cli.sh
source "${SCRIPT_DIR}/lib/cli.sh"
# shellcheck source=lib/platform.sh
source "${SCRIPT_DIR}/lib/platform.sh"
# shellcheck source=lib/packages-ubuntu.sh
source "${SCRIPT_DIR}/lib/packages-ubuntu.sh"
# shellcheck source=lib/packages-opensuse.sh
source "${SCRIPT_DIR}/lib/packages-opensuse.sh"
# shellcheck source=lib/toolsets.sh
source "${SCRIPT_DIR}/lib/toolsets.sh"
# shellcheck source=lib/artifacts.sh
source "${SCRIPT_DIR}/lib/artifacts.sh"
# shellcheck source=lib/prompt.sh
source "${SCRIPT_DIR}/lib/prompt.sh"

main() {
  set -Eeuo pipefail
  TEMP_DIR=$(mktemp -d)
  trap cleanup EXIT
  trap 'exit 1' INT TERM
  parse_arguments "$@"
  select_toolsets
  validate_toolsets
  detect_platform
  confirm_installation

  case "$DISTRO" in
  ubuntu) install_ubuntu_packages ;;
  opensuse) install_opensuse_packages ;;
  esac

  install_markdown_tools
  if toolset_enabled containers && "$CONFIGURE_DOCKER_GROUP"; then
    configure_docker_group
  fi
  install_upstream_tools
  if toolset_enabled general; then
    configure_bash_prompt
  fi

  if ! "$DRY_RUN"; then
    log "installation complete; start a new Bash session or run: source ~/.bashrc"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
