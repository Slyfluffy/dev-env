#!/usr/bin/env bash

# Install selected development toolsets on supported Ubuntu and OpenSUSE hosts.
# Distribution packages provide system integrations; upstream releases are used
# for tools where the latest version is important.
set -Eeuo pipefail

SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_NAME
readonly PROMPT_START="# >>> dev-env prompt >>>"

DRY_RUN=false
ASSUME_YES=false
SELECTED_TOOLSETS=()

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--dry-run] [--yes]

  --dry-run  Show commands without changing the system
  --yes      Do not ask for confirmation
EOF
}

log() {
  printf '[setup] %s\n' "$*"
}

die() {
  printf '[setup] error: %s\n' "$*" >&2
  exit 1
}

run() {
  if "$DRY_RUN"; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

for argument in "$@"; do
  case "$argument" in
  --dry-run) DRY_RUN=true ;;
  --yes) ASSUME_YES=true ;;
  -h | --help)
    usage
    exit 0
    ;;
  *) die "unknown argument: $argument" ;;
  esac
done

select_toolsets() {
  # Keep selection interactive so the same command works for first-time setup
  # and subsequent partial installs without requiring shell-specific syntax.
  local selection option
  printf '\nAvailable toolsets:\n'
  printf '  1) all\n'
  printf '  2) general\n'
  printf '  3) bash\n'
  printf '  4) python\n'
  printf '  5) go\n'
  printf '  6) containers\n'
  printf '  7) kubernetes\n'
  printf '  8) markdown\n\n'
  read -r -p "Select toolsets (comma-separated numbers, default: all): " selection
  selection=${selection:-1}

  if [[ "$selection" == 1 ]]; then
    SELECTED_TOOLSETS=(general bash python go containers kubernetes markdown)
    return
  fi

  IFS=',' read -r -a selection_options <<<"$selection"
  for option in "${selection_options[@]}"; do
    case "$option" in
    2) SELECTED_TOOLSETS+=(general) ;;
    3) SELECTED_TOOLSETS+=(bash) ;;
    4) SELECTED_TOOLSETS+=(python) ;;
    5) SELECTED_TOOLSETS+=(go) ;;
    6) SELECTED_TOOLSETS+=(containers) ;;
    7) SELECTED_TOOLSETS+=(kubernetes) ;;
    8) SELECTED_TOOLSETS+=(markdown) ;;
    *) die "invalid toolset selection: $option" ;;
    esac
  done
}

select_toolsets

toolset_enabled() {
  local requested=$1 toolset
  for toolset in "${SELECTED_TOOLSETS[@]}"; do
    [[ "$toolset" == "$requested" ]] && return 0
  done
  return 1
}

for toolset in "${SELECTED_TOOLSETS[@]}"; do
  case "$toolset" in
  general | bash | python | go | containers | kubernetes | markdown) ;;
  *) die "unknown toolset: $toolset" ;;
  esac
done

[[ -r /etc/os-release ]] || die "cannot identify the operating system"
# shellcheck source=/dev/null
source /etc/os-release

case "${ID:-}" in
ubuntu)
  DISTRO=ubuntu
  ;;
opensuse-tumbleweed | opensuse-leap | opensuse)
  DISTRO=opensuse
  ;;
*)
  die "unsupported distribution: ${PRETTY_NAME:-unknown}"
  ;;
esac

# Release assets currently use these architecture names for Linux binaries.
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

if ! "$ASSUME_YES" && ! "$DRY_RUN"; then
  read -r -p "Install development tools on ${PRETTY_NAME}? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || {
    log "cancelled"
    exit 0
  }
fi

install_ubuntu_packages() {
  local packages=(ca-certificates curl)
  if toolset_enabled general; then
    packages+=(git wget nano pre-commit)
  fi
  if toolset_enabled bash; then
    packages+=(shellcheck bats)
  fi
  toolset_enabled python && packages+=(python3)
  toolset_enabled go && packages+=(golang)
  toolset_enabled containers && packages+=(golang)
  toolset_enabled markdown && packages+=(nodejs npm)
  run "${SUDO[@]}" apt-get update
  run "${SUDO[@]}" apt-get install -y "${packages[@]}"

  # Docker's official repository provides the Engine and Compose CLI plugin.
  if ! toolset_enabled containers; then
    return
  fi
  if "$DRY_RUN"; then
    log "would configure Docker's official Ubuntu repository"
    return
  fi

  local keyring=/etc/apt/keyrings/docker.gpg
  "${SUDO[@]}" install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
    "${SUDO[@]}" gpg --dearmor --yes -o "$keyring"
  "${SUDO[@]}" chmod a+r "$keyring"
  printf 'deb [arch=%s signed-by=%s] https://download.docker.com/linux/ubuntu %s stable\n' \
    "$ARCH" "$keyring" "$VERSION_CODENAME" |
    "${SUDO[@]}" tee /etc/apt/sources.list.d/docker.list >/dev/null
  run "${SUDO[@]}" apt-get update
  run "${SUDO[@]}" apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin
  run "${SUDO[@]}" apt-get install -y docker-compose-plugin
  run "${SUDO[@]}" systemctl enable --now docker
}

install_opensuse_packages() {
  local packages=(ca-certificates curl)
  if toolset_enabled general; then
    packages+=(git wget nano python313-pre-commit)
  fi
  if toolset_enabled bash; then
    packages+=(ShellCheck bats)
  fi
  if toolset_enabled python; then
    packages+=(python3 python313-ruff python313-pytest python313-pytest-cov)
  fi
  toolset_enabled go && packages+=(go)
  toolset_enabled containers && packages+=(go)
  toolset_enabled containers && packages+=(docker)
  toolset_enabled markdown && packages+=(nodejs npm)
  run "${SUDO[@]}" zypper --non-interactive refresh
  run "${SUDO[@]}" zypper --non-interactive install "${packages[@]}"

  # OpenSUSE supplies Docker through zypper; Compose is filled in upstream
  # when the distribution package does not provide the CLI plugin.
  if ! toolset_enabled containers; then
    return
  fi
  if "$DRY_RUN"; then
    log "would install Docker Compose from Docker's upstream repository"
    return
  fi

  run "${SUDO[@]}" systemctl enable --now docker
  if ! docker compose version >/dev/null 2>&1; then
    log "installing the Docker Compose plugin from its latest upstream release"
    local compose_arch
    case "$ARCH" in
    amd64) compose_arch=x86_64 ;;
    arm64) compose_arch=aarch64 ;;
    esac
    install_github_asset \
      docker/compose \
      "docker-compose-linux-${compose_arch}" \
      /usr/local/lib/docker/cli-plugins/docker-compose
  fi
}

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
    run "${SUDO[@]}" npm install --global markdownlint-cli2
  fi
}

github_latest_tag() {
  local repository=$1
  curl -fsSL "https://api.github.com/repos/${repository}/releases/latest" |
    sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' |
    head -n 1
}

install_github_asset() {
  local repository=$1
  local asset=$2
  local destination=$3
  local tag
  local temporary_file

  # Resolve the tag separately so assets can be installed without curl|sh.
  tag=$(github_latest_tag "$repository")
  [[ -n "$tag" ]] || die "could not determine the latest release for $repository"
  temporary_file=$(mktemp)
  curl -fL --retry 3 \
    "https://github.com/${repository}/releases/download/${tag}/${asset}" \
    -o "$temporary_file"
  run chmod +x "$temporary_file"
  run "${SUDO[@]}" install -d -m 0755 "$(dirname "$destination")"
  run "${SUDO[@]}" install -m 0755 "$temporary_file" "$destination"
  rm -f "$temporary_file"
}

install_upstream_tools() {
  if "$DRY_RUN"; then
    log "would install selected latest upstream tools"
    return
  fi

  if toolset_enabled bash; then
    local shfmt_tag
    shfmt_tag=$(github_latest_tag mvdan/sh)
    install_github_asset mvdan/sh "shfmt_${shfmt_tag}_linux_${ARCH}" /usr/local/bin/shfmt
  fi

  if toolset_enabled containers; then
    local hadolint_arch
    case "$ARCH" in
    amd64) hadolint_arch=x86_64 ;;
    arm64) hadolint_arch=arm64 ;;
    esac
    install_github_asset hadolint/hadolint \
      "hadolint-linux-${hadolint_arch}" /usr/local/bin/hadolint
    install_github_asset sigstore/cosign "cosign-linux-${ARCH}" /usr/local/bin/cosign
    local go_bin
    go_bin=$(mktemp -d)
    GOBIN="$go_bin" go install github.com/reteps/dockerfmt@latest
    run "${SUDO[@]}" install -m 0755 "$go_bin/dockerfmt" /usr/local/bin/dockerfmt
    rm -rf "$go_bin"
  fi

  if toolset_enabled kubernetes; then
    local kubectl_version kubectl_file
    kubectl_version=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
    kubectl_file=$(mktemp)
    curl -fL --retry 3 \
      "https://dl.k8s.io/release/${kubectl_version}/bin/linux/${ARCH}/kubectl" \
      -o "$kubectl_file"
    run chmod +x "$kubectl_file"
    run "${SUDO[@]}" install -m 0755 "$kubectl_file" /usr/local/bin/kubectl
    rm -f "$kubectl_file"
    install_github_asset kubernetes/minikube "minikube-linux-${ARCH}" /usr/local/bin/minikube
  fi

  if toolset_enabled python; then
    local uv_platform uv_tag uv_archive uv_directory uv_bin
    case "$ARCH" in
    amd64) uv_platform=x86_64-unknown-linux-gnu ;;
    arm64) uv_platform=aarch64-unknown-linux-gnu ;;
    esac
    uv_tag=$(github_latest_tag astral-sh/uv)
    [[ -n "$uv_tag" ]] || die "could not determine the latest release for astral-sh/uv"
    uv_archive=$(mktemp)
    uv_directory=$(mktemp -d)
    curl -fL --retry 3 \
      "https://github.com/astral-sh/uv/releases/download/${uv_tag}/uv-${uv_platform}.tar.gz" \
      -o "$uv_archive"
    tar -xzf "$uv_archive" -C "$uv_directory"
    uv_bin="${uv_directory}/uv-${uv_platform}/uv"
    [[ -x "$uv_bin" ]] || die "uv archive did not contain the expected binary"
    run "${SUDO[@]}" install -m 0755 "$uv_bin" /usr/local/bin/uv
    rm -f "$uv_archive"
    rm -rf "$uv_directory"
    if [[ "$DISTRO" != opensuse ]]; then
      run uv tool install --force ruff
      run uv tool install --force --with pytest-cov pytest
    fi
  fi
}

configure_bash_prompt() {
  local bashrc="${HOME}/.bashrc"
  local temporary_file

  # The marker makes repeated runs idempotent and avoids duplicating PS1 code.
  if "$DRY_RUN"; then
    log "would configure ${bashrc} with the colored Git-aware prompt"
    return
  fi

  touch "$bashrc"
  if grep -Fq "$PROMPT_START" "$bashrc"; then
    log "Bash prompt already configured in ${bashrc}"
    return
  fi

  temporary_file=$(mktemp)
  cat "$bashrc" >"$temporary_file"
  cat >>"$temporary_file" <<'EOF'

# >>> dev-env prompt >>>
_dev_env_prompt() {
    local reset='\[\e[0m\]'
    local user_color path_color branch_color branch

    if (( EUID == 0 )); then
        user_color='\[\e[31m\]'
        path_color='\[\e[31m\]'
    else
        user_color='\[\e[32m\]'
        path_color='\[\e[34m\]'
    fi

    branch_color='\[\e[33m\]'
    branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
    PS1="${user_color}\u@\h${reset}:${path_color}\w${reset}"
    PS1+="\$"
    [[ -n "$branch" ]] && PS1+=" ${branch_color}[${branch}]${reset}"
    PS1+=" "
}
PROMPT_COMMAND="_dev_env_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
# <<< dev-env prompt <<<
EOF
  run install -m 0644 "$temporary_file" "$bashrc"
  rm -f "$temporary_file"
  log "configured ${bashrc}"
}

case "$DISTRO" in
ubuntu) install_ubuntu_packages ;;
opensuse) install_opensuse_packages ;;
esac

install_markdown_tools

if toolset_enabled containers; then
  configure_docker_group
fi

install_upstream_tools
if toolset_enabled general; then
  configure_bash_prompt
fi

if ! "$DRY_RUN"; then
  log "installation complete; start a new Bash session or run: source ~/.bashrc"
fi
