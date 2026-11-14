#!/usr/bin/env bash
# shellcheck disable=SC2034

SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_NAME
readonly PROMPT_START="# >>> dev-env prompt >>>"

DRY_RUN=false
ASSUME_YES=false
CONFIGURE_DOCKER_GROUP=false
SELECTED_TOOLSETS=()
OPENSUSE_PYTHON_UV_TOOLS=()
TEMP_DIR=
PROMPT_TEMP_FILE=
OS_RELEASE_FILE=/etc/os-release

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

cleanup() {
  [[ -n "$PROMPT_TEMP_FILE" ]] && rm -f "$PROMPT_TEMP_FILE"
  [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}
