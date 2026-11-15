#!/usr/bin/env bats

@test "parses dry-run and Docker group opt-in flags" {
  run bash -c '
    source "$1"
    parse_arguments --dry-run --docker-group
    printf "%s %s\n" "$DRY_RUN" "$CONFIGURE_DOCKER_GROUP"
  ' bash "${BATS_TEST_DIRNAME}/../setup.bash"

  [ "$status" -eq 0 ]
  [ "$output" = "true true" ]
}

@test "selects requested toolsets without installing anything" {
  run bash -c '
    source "$1"
    select_toolsets <<< "3,7"
    printf "%s\n" "${SELECTED_TOOLSETS[*]}"
  ' bash "${BATS_TEST_DIRNAME}/../setup.bash"

  [ "$status" -eq 0 ]
  [ "${output##*$'\n'}" = "bash kubernetes" ]
}

@test "selects the Ansible toolset" {
  run bash -c '
    source "$1"
    select_toolsets <<< "9"
    printf "%s\n" "${SELECTED_TOOLSETS[*]}"
  ' bash "${BATS_TEST_DIRNAME}/../setup.bash"

  [ "$status" -eq 0 ]
  [ "${output##*$'\n'}" = "ansible" ]
}

@test "parses Ubuntu release metadata needed by Docker setup" {
  run bash -c '
    source "$1"
    release_file=$(mktemp)
    trap "rm -f \"$release_file\"" EXIT
    printf "%s\n" \
      "ID=ubuntu" \
      "PRETTY_NAME=\"Ubuntu Test\"" \
      "VERSION_CODENAME=jammy" >"$release_file"
    OS_RELEASE_FILE=$release_file
    detect_platform
    printf "%s %s %s\n" "$DISTRO" "$PRETTY_NAME" "$VERSION_CODENAME"
  ' bash "${BATS_TEST_DIRNAME}/../setup.bash"

  [ "$status" -eq 0 ]
  [ "${output##*$'\n'}" = "ubuntu Ubuntu Test jammy" ]
}

@test "has a pinned kubectl digest for each supported architecture" {
  run bash -c '
    source "$1"
    expected_kubectl_digest amd64
    expected_kubectl_digest arm64
  ' bash "${BATS_TEST_DIRNAME}/../setup.bash"
  [ "$status" -eq 0 ]
  [ "${#output}" -eq 129 ]
}

@test "has a pinned Helm digest for each supported architecture" {
  run bash -c '
    source "$1"
    expected_helm_digest amd64
    expected_helm_digest arm64
  ' bash "${BATS_TEST_DIRNAME}/../setup.bash"
  [ "$status" -eq 0 ]
  [ "${#output}" -eq 129 ]
}

@test "all pinned GitHub asset digests have the expected format" {
  run bash -c '
    source "$1"
    expected_asset_digest mvdan/sh v3.14.1 shfmt_v3.14.1_linux_amd64
    expected_asset_digest hadolint/hadolint v2.15.1 hadolint-linux-x86_64
    expected_asset_digest sigstore/cosign v3.1.4 cosign-linux-amd64
    expected_asset_digest kubernetes/minikube v1.39.0 minikube-linux-amd64
    expected_asset_digest astral-sh/uv 0.13.8 uv-x86_64-unknown-linux-gnu.tar.gz
    expected_asset_digest docker/compose v5.7.1 docker-compose-linux-x86_64
  ' bash "${BATS_TEST_DIRNAME}/../setup.bash"
  [ "$status" -eq 0 ]
  [ "$(printf "%s\n" "$output" | awk 'length != 64 || $0 !~ /^[[:xdigit:]]+$/ { bad=1 } END { print bad + 0 }')" -eq 0 ]
}
