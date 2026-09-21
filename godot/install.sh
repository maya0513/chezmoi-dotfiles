#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=lib/app-manager.sh
source "${SCRIPT_DIR}/../lib/app-manager.sh"
# shellcheck source=godot/config.sh
source "${SCRIPT_DIR}/config.sh"

readonly RELEASE_REPOSITORY="godotengine/godot"
readonly RELEASE_API="https://api.github.com/repos/${RELEASE_REPOSITORY}/releases/latest"
readonly RELEASE_BASE_URL="https://github.com/${RELEASE_REPOSITORY}/releases/download"

WORK_DIR=""

cleanup() {
  if [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]]; then
    rm -rf -- "${WORK_DIR}"
  fi
}

trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage: godot/install.sh [VERSION]

Install a stable Godot release into /opt/godot/<version>.
VERSION may be X.Y.Z, X.Y.Z-stable, latest, or omitted.
The installed version is printed to standard output.
EOF
}

resolve_version() {
  local requested="${1:-latest}"
  local tag

  if [[ -z "${requested}" || "${requested}" == "latest" ]]; then
    info "Resolving the latest stable Godot release..."
    tag="$({
      curl --fail --silent --show-error --location --retry 3 \
        --header 'Accept: application/vnd.github+json' \
        --header 'X-GitHub-Api-Version: 2022-11-28' \
        "${RELEASE_API}"
    } | jq -er '.tag_name')" || die "could not resolve the latest Godot release"
    canonical_version "${tag}"
  else
    canonical_version "${requested}"
  fi
}

main() {
  if (($# > 1)); then
    usage >&2
    exit 2
  fi
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  require_commands curl jq unzip sha512sum awk mktemp uname cp
  require_linux_x86_64

  local version
  version="$(resolve_version "${1:-latest}")"
  if is_managed_installation "${version}"; then
    info "Godot ${version} is already installed."
    printf '%s\n' "${version}"
    return 0
  fi

  local target
  target="$(version_path "${version}")"
  if [[ -e "${target}" || -L "${target}" ]]; then
    die "${target} exists but is not a complete managed installation"
  fi

  require_root_access
  WORK_DIR="$(mktemp -d "/tmp/godot-${version}.XXXXXX")"

  local tag="${version}-stable"
  local archive="Godot_v${tag}_linux.x86_64.zip"
  local archive_path="${WORK_DIR}/${archive}"
  local sums_path="${WORK_DIR}/SHA512-SUMS.txt"

  info "Downloading Godot ${version}..."
  curl --fail --silent --show-error --location --retry 3 \
    --output "${archive_path}" "${RELEASE_BASE_URL}/${tag}/${archive}"
  curl --fail --silent --show-error --location --retry 3 \
    --output "${sums_path}" "${RELEASE_BASE_URL}/${tag}/SHA512-SUMS.txt"

  local checksum
  checksum="$(awk -v file="${archive}" '$2 == file || $2 == "*" file { print $1; exit }' "${sums_path}")"
  [[ "${checksum}" =~ ^[[:xdigit:]]{128}$ ]] ||
    die "could not find a valid SHA-512 checksum for ${archive}"
  printf '%s  %s\n' "${checksum}" "${archive}" >"${WORK_DIR}/archive.sha512"
  (cd "${WORK_DIR}" && sha512sum --check --strict archive.sha512 >&2)

  local extracted_dir="${WORK_DIR}/extracted"
  local staged_dir="${WORK_DIR}/staged"
  mkdir -p -- "${extracted_dir}" "${staged_dir}"
  unzip -q "${archive_path}" -d "${extracted_dir}"

  local extracted_binary="${extracted_dir}/Godot_v${tag}_linux.x86_64"
  [[ -f "${extracted_binary}" ]] || die "archive did not contain the expected Godot executable"
  chmod +x "${extracted_binary}"
  mv -- "${extracted_binary}" "${staged_dir}/godot"
  printf '%s %s\n' "${APP_NAME}" "${version}" >"${staged_dir}/.managed-by-chezmoi-dotfiles"

  publish_installation "${staged_dir}" "${version}"
  info "Installed Godot ${version} in ${target}."
  printf '%s\n' "${version}"
}

main "$@"
