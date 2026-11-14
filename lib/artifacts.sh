#!/usr/bin/env bash

expected_asset_digest() {
  local repository=$1
  local tag=$2
  local asset=$3

  case "${repository}:${tag}:${asset}" in
  mvdan/sh:v3.14.1:shfmt_v3.14.1_linux_amd64)
    printf '%s\n' 76e77641faa025814b77f153b29796b8e6fa2fca03e0c76a691608b86c7ea7bf
    ;;
  mvdan/sh:v3.14.1:shfmt_v3.14.1_linux_arm64)
    printf '%s\n' 5f2db09dae91fca848f7adbdd014632e921a383863a2ad7e0450ad3aba0c6489
    ;;
  hadolint/hadolint:v2.15.1:hadolint-linux-x86_64)
    printf '%s\n' c7187db94eeeeca956519a6af171adc31453941a1e777961f6e680f697c8c507
    ;;
  hadolint/hadolint:v2.15.1:hadolint-linux-arm64)
    printf '%s\n' f6198ef8090f404dbb771abfee086eb8c48ac177f30da7fd3510aca35b344b5d
    ;;
  sigstore/cosign:v3.1.4:cosign-linux-amd64)
    printf '%s\n' 424e2c97d0b45fd7a6b608a87f090f35633f4c23ece5f092d48bba11aaf4bbfa
    ;;
  sigstore/cosign:v3.1.4:cosign-linux-arm64)
    printf '%s\n' ade83b7aac62e131cacfe96d958948b2150cc9efec46a570a2649b8e27dedad2
    ;;
  kubernetes/minikube:v1.39.0:minikube-linux-amd64)
    printf '%s\n' b738496da01be06bbaf80c688f57ce25acd3849fbb518155f3a88e03ef555aa4
    ;;
  kubernetes/minikube:v1.39.0:minikube-linux-arm64)
    printf '%s\n' 202f331cb677761c5aec81c58472d16d65707358b9f66226210be3fe3275b1c3
    ;;
  astral-sh/uv:0.13.8:uv-x86_64-unknown-linux-gnu.tar.gz)
    printf '%s\n' 5acfd9177cfecf0bf87578f059728215ccc884388988f55f7a65041b57387d91
    ;;
  astral-sh/uv:0.13.8:uv-aarch64-unknown-linux-gnu.tar.gz)
    printf '%s\n' 74f2f5c6024d397481db228db8fc25eed420db192243f88438c118e7e013e585
    ;;
  docker/compose:v5.7.1:docker-compose-linux-x86_64)
    printf '%s\n' af426722a8af5de812fcee30cc1c39f0639f5f723cbadefb25e5d4db054064cf
    ;;
  docker/compose:v5.7.1:docker-compose-linux-aarch64)
    printf '%s\n' f2f49f903240895fa764c0dca3a14548b754ad9426f6b609ccaf55ec5a3aa2a5
    ;;
  *)
    die "no pinned SHA256 digest for ${repository}/${tag}/${asset}"
    ;;
  esac
}

verify_sha256() {
  local file=$1
  local expected=$2

  [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || die "invalid SHA256 digest for $file"
  printf '%s  %s\n' "$expected" "$file" | sha256sum --check --status - ||
    die "SHA256 verification failed for $file"
}

install_github_asset() {
  local repository=$1
  local asset=$2
  local destination=$3
  local tag digest temporary_file

  tag=$4
  [[ -n "$tag" ]] || die "a pinned release tag is required for $repository/$asset"
  if "$DRY_RUN"; then
    digest=$(expected_asset_digest "$repository" "$tag" "$asset")
    log "would download and verify ${repository}/${asset} at ${tag} (SHA256 ${digest})"
    run curl -fL --retry 3 \
      "https://github.com/${repository}/releases/download/${tag}/${asset}" \
      -o "$TEMP_DIR/download"
    run "${SUDO[@]}" install -m 0755 "$TEMP_DIR/download" "$destination"
    return
  fi
  digest=$(expected_asset_digest "$repository" "$tag" "$asset")
  temporary_file=$(mktemp "$TEMP_DIR/download.XXXXXX")
  curl -fL --retry 3 \
    "https://github.com/${repository}/releases/download/${tag}/${asset}" \
    -o "$temporary_file"
  verify_sha256 "$temporary_file" "$digest"
  run chmod +x "$temporary_file"
  run "${SUDO[@]}" install -d -m 0755 "$(dirname "$destination")"
  run "${SUDO[@]}" install -m 0755 "$temporary_file" "$destination"
  rm -f "$temporary_file"
}

download_github_asset() {
  local repository=$1
  local asset=$2
  local tag=$3
  local destination=$4
  local digest

  if "$DRY_RUN"; then
    digest=$(expected_asset_digest "$repository" "$tag" "$asset")
    log "would download and verify ${repository}/${asset} at ${tag} (SHA256 ${digest})"
    run curl -fL --retry 3 \
      "https://github.com/${repository}/releases/download/${tag}/${asset}" \
      -o "$destination"
    return
  fi

  digest=$(expected_asset_digest "$repository" "$tag" "$asset")
  curl -fL --retry 3 \
    "https://github.com/${repository}/releases/download/${tag}/${asset}" \
    -o "$destination"
  verify_sha256 "$destination" "$digest"
}

install_uv() {
  local uv_platform uv_archive uv_directory uv_bin
  case "$ARCH" in
  amd64) uv_platform=x86_64-unknown-linux-gnu ;;
  arm64) uv_platform=aarch64-unknown-linux-gnu ;;
  esac

  uv_archive="$TEMP_DIR/uv.tar.gz"
  uv_directory="$TEMP_DIR/uv"
  download_github_asset astral-sh/uv "uv-${uv_platform}.tar.gz" \
    "$UV_TAG" "$uv_archive"
  if "$DRY_RUN"; then
    run tar -xzf "$uv_archive" -C "$uv_directory"
    run "${SUDO[@]}" install -m 0755 \
      "$uv_directory/uv-${uv_platform}/uv" /usr/local/bin/uv
    return
  fi
  mkdir -p "$uv_directory"
  tar -xzf "$uv_archive" -C "$uv_directory"
  uv_bin="${uv_directory}/uv-${uv_platform}/uv"
  [[ -x "$uv_bin" ]] || die "uv archive did not contain the expected binary"
  run "${SUDO[@]}" install -m 0755 "$uv_bin" /usr/local/bin/uv
}

install_kubectl() {
  local kubectl_file="$TEMP_DIR/kubectl"
  local kubectl_digest

  kubectl_digest=$(expected_kubectl_digest "$ARCH")
  if "$DRY_RUN"; then
    run curl -fL --retry 3 \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
      -o "$kubectl_file"
    log "would verify kubectl against pinned SHA256 ${kubectl_digest}"
    run "${SUDO[@]}" install -m 0755 "$kubectl_file" /usr/local/bin/kubectl
    return
  fi

  curl -fL --retry 3 \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
    -o "$kubectl_file"
  verify_sha256 "$kubectl_file" "$kubectl_digest"
  run "${SUDO[@]}" install -m 0755 "$kubectl_file" /usr/local/bin/kubectl
}

expected_kubectl_digest() {
  case "$1" in
  amd64) printf '%s\n' c04487523e7aa7d1493f7808174c899db93d7a9cf57531420cd76b9bd415f8f4 ;;
  arm64) printf '%s\n' fcc16f63186659d9722014b7e02d5fdd2d4e669cb8c0ab66365d7d3b8ba03509 ;;
  *) die "no pinned kubectl SHA256 digest for architecture: $1" ;;
  esac
}

install_dockerfmt() {
  local go_bin="$TEMP_DIR/dockerfmt"
  if "$DRY_RUN"; then
    run env GOBIN="$go_bin" \
      go install "github.com/reteps/dockerfmt@${DOCKERFMT_REVISION}"
    run "${SUDO[@]}" install -m 0755 "$go_bin/dockerfmt" /usr/local/bin/dockerfmt
    return
  fi

  mkdir -p "$go_bin"
  GOBIN="$go_bin" go install "github.com/reteps/dockerfmt@${DOCKERFMT_REVISION}"
  run "${SUDO[@]}" install -m 0755 "$go_bin/dockerfmt" /usr/local/bin/dockerfmt
}

install_upstream_tools() {
  if toolset_enabled bash; then
    install_github_asset mvdan/sh "shfmt_${SHFMT_TAG}_linux_${ARCH}" \
      /usr/local/bin/shfmt "$SHFMT_TAG"
  fi

  if toolset_enabled containers; then
    local hadolint_arch
    case "$ARCH" in
    amd64) hadolint_arch=x86_64 ;;
    arm64) hadolint_arch=arm64 ;;
    esac
    install_github_asset hadolint/hadolint \
      "hadolint-linux-${hadolint_arch}" /usr/local/bin/hadolint "$HADOLINT_TAG"
    install_github_asset sigstore/cosign "cosign-linux-${ARCH}" \
      /usr/local/bin/cosign "$COSIGN_TAG"
    install_dockerfmt
  fi

  if toolset_enabled kubernetes; then
    install_kubectl
    install_github_asset kubernetes/minikube "minikube-linux-${ARCH}" \
      /usr/local/bin/minikube "$MINIKUBE_TAG"
  fi

  if toolset_enabled python || ((${#OPENSUSE_PYTHON_UV_TOOLS[@]} > 0)); then
    install_uv
    if [[ "$DISTRO" != opensuse ]]; then
      run uv tool install --force "ruff==${RUFF_VERSION}"
      run uv tool install --force \
        --with "pytest-cov==${PYTEST_COV_VERSION}" \
        "pytest==${PYTEST_VERSION}"
    else
      local python_uv_tool
      for python_uv_tool in "${OPENSUSE_PYTHON_UV_TOOLS[@]}"; do
        case "$python_uv_tool" in
        pre-commit)
          run uv tool install --force "pre-commit==${PRE_COMMIT_VERSION}"
          ;;
        pytest-cov)
          run uv tool install --force \
            --with "pytest-cov==${PYTEST_COV_VERSION}" \
            "pytest==${PYTEST_VERSION}"
          ;;
        pytest)
          run uv tool install --force "pytest==${PYTEST_VERSION}"
          ;;
        ruff) run uv tool install --force "ruff==${RUFF_VERSION}" ;;
        *) die "unsupported uv tool fallback: $python_uv_tool" ;;
        esac
      done
    fi
  fi
}
