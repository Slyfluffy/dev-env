#!/usr/bin/env bash
# shellcheck disable=SC2034
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--dry-run] [--yes] [--docker-group]

  --dry-run  Show commands without changing the system
  --yes      Do not ask for confirmation
  --docker-group  Add the current user to Docker's root-equivalent group
EOF
}

parse_arguments() {
  local argument
  for argument in "$@"; do
    case "$argument" in
    --dry-run) DRY_RUN=true ;;
    --yes) ASSUME_YES=true ;;
    --docker-group) CONFIGURE_DOCKER_GROUP=true ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "unknown argument: $argument" ;;
    esac
  done
}

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
  printf '  8) markdown\n'
  printf '  9) ansible\n\n'
  read -r -p "Select toolsets (comma-separated numbers, default: all): " selection
  selection=${selection:-1}

  if [[ "$selection" == 1 ]]; then
    SELECTED_TOOLSETS=(general bash python go containers kubernetes markdown ansible)
    return
  fi

  IFS=',' read -r -a selection_options <<<"$selection"
  for option in "${selection_options[@]}"; do
    option="${option#"${option%%[![:space:]]*}"}"
    option="${option%"${option##*[![:space:]]}"}"
    case "$option" in
    1)
      SELECTED_TOOLSETS=(general bash python go containers kubernetes markdown ansible)
      return
      ;;
    2) SELECTED_TOOLSETS+=(general) ;;
    3) SELECTED_TOOLSETS+=(bash) ;;
    4) SELECTED_TOOLSETS+=(python) ;;
    5) SELECTED_TOOLSETS+=(go) ;;
    6) SELECTED_TOOLSETS+=(containers) ;;
    7) SELECTED_TOOLSETS+=(kubernetes) ;;
    8) SELECTED_TOOLSETS+=(markdown) ;;
    9) SELECTED_TOOLSETS+=(ansible) ;;
    *) die "invalid toolset selection: $option" ;;
    esac
  done
}

validate_toolsets() {
  local toolset
  for toolset in "${SELECTED_TOOLSETS[@]}"; do
    case "$toolset" in
    general | bash | python | go | containers | kubernetes | markdown | ansible) ;;
    *) die "unknown toolset: $toolset" ;;
    esac
  done
}
