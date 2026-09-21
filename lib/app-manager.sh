#!/usr/bin/env bash

# Shared lifecycle helpers for the Godot and Blender management scripts.
# The caller must define APP_NAME, APP_ROOT, APP_EXECUTABLE, FRONTEND_LINK,
# and normalize_version before using these functions.

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*" >&2
}

require_commands() {
  local command_name
  local -a missing=()

  for command_name in "$@"; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
      missing+=("${command_name}")
    fi
  done

  if ((${#missing[@]} > 0)); then
    die "required commands are missing: ${missing[*]}"
  fi
}

require_linux_x86_64() {
  [[ "$(uname -s)" == "Linux" ]] || die "only Linux is supported"
  [[ "$(uname -m)" == "x86_64" ]] || die "only Linux x86_64 is supported"
}

canonical_version() {
  local version
  version="$(normalize_version "$1")" ||
    die "unsupported ${APP_NAME} version '$1'; expected ${VERSION_EXAMPLE}"
  printf '%s\n' "${version}"
}

version_path() {
  printf '%s/%s\n' "${APP_ROOT}" "$1"
}

is_managed_installation() {
  local version="$1"
  local target
  target="$(version_path "${version}")"
  local marker="${target}/.managed-by-chezmoi-dotfiles"

  [[ -d "${target}" ]] &&
    [[ -x "${target}/${APP_EXECUTABLE}" ]] &&
    [[ -f "${marker}" ]] &&
    [[ "$(<"${marker}")" == "${APP_NAME} ${version}" ]]
}

get_current_version() {
  local current_link="${APP_ROOT}/current"
  [[ -L "${current_link}" ]] || return 1

  local target
  target="$(readlink "${current_link}")"
  [[ "${target}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 2
  printf '%s\n' "${target}"
}

run_as_root() {
  if ((EUID == 0)); then
    "$@"
  else
    sudo -- "$@"
  fi
}

require_root_access() {
  if ((EUID != 0)); then
    require_commands sudo
    sudo -v
  fi
}

publish_installation() {
  local staged_dir="$1"
  local version="$2"
  local target
  target="$(version_path "${version}")"
  local root_staging="${APP_ROOT}/.install-${version}.$$.tmp"

  if [[ -e "${target}" || -L "${target}" ]]; then
    die "${target} already exists but is not a complete managed installation"
  fi

  require_root_access
  run_as_root mkdir -p -- "${APP_ROOT}"
  run_as_root rm -rf -- "${root_staging}"
  if ! run_as_root mkdir -- "${root_staging}"; then
    die "could not create an installation staging directory in ${APP_ROOT}"
  fi

  if ! run_as_root cp -a --no-preserve=ownership -- "${staged_dir}/." "${root_staging}/"; then
    run_as_root rm -rf -- "${root_staging}"
    die "could not publish ${APP_NAME} ${version}"
  fi

  if ! run_as_root mv -T -- "${root_staging}" "${target}"; then
    run_as_root rm -rf -- "${root_staging}"
    die "could not publish ${APP_NAME} ${version}"
  fi
}

validate_frontend_link() {
  local expected_destination="${APP_ROOT}/current/${APP_EXECUTABLE}"

  if [[ -L "${FRONTEND_LINK}" ]]; then
    local actual_destination
    actual_destination="$(readlink "${FRONTEND_LINK}")"
    [[ "${actual_destination}" == "${expected_destination}" ]] ||
      die "${FRONTEND_LINK} points to unmanaged destination ${actual_destination}"
  elif [[ -e "${FRONTEND_LINK}" ]]; then
    die "${FRONTEND_LINK} already exists and is not managed by these scripts"
  fi
}

activate_version() {
  local version="$1"
  local target
  target="$(version_path "${version}")"
  is_managed_installation "${version}" ||
    die "${APP_NAME} ${version} is not installed by these scripts"

  local current_link="${APP_ROOT}/current"
  if [[ -L "${current_link}" ]]; then
    local previous_version
    previous_version="$(readlink "${current_link}")"
    if [[ ! "${previous_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
      ! is_managed_installation "${previous_version}"; then
      die "${current_link} points to an unmanaged destination ${previous_version}"
    fi
  elif [[ -e "${current_link}" ]]; then
    die "${current_link} exists and is not a symlink"
  fi
  validate_frontend_link
  require_root_access

  local current_staging="${APP_ROOT}/.current.$$.tmp"
  local frontend_staging
  frontend_staging="$(dirname "${FRONTEND_LINK}")/.${APP_NAME}.$$.tmp"
  local expected_destination="${APP_ROOT}/current/${APP_EXECUTABLE}"
  local created_frontend=0

  run_as_root rm -f -- "${current_staging}" "${frontend_staging}"
  run_as_root ln -s -- "${version}" "${current_staging}"

  if [[ ! -L "${FRONTEND_LINK}" ]]; then
    run_as_root ln -s -- "${expected_destination}" "${frontend_staging}"
    if ! run_as_root mv -T -- "${frontend_staging}" "${FRONTEND_LINK}"; then
      run_as_root rm -f -- "${current_staging}" "${frontend_staging}"
      die "could not create ${FRONTEND_LINK}"
    fi
    created_frontend=1
  fi

  if ! run_as_root mv -Tf -- "${current_staging}" "${current_link}"; then
    run_as_root rm -f -- "${current_staging}"
    if ((created_frontend)); then
      run_as_root rm -f -- "${FRONTEND_LINK}"
    fi
    die "could not activate ${APP_NAME} ${version}"
  fi

  info "${APP_NAME} ${version} is active."
}

uninstall_version() {
  local version="$1"
  local target
  target="$(version_path "${version}")"

  is_managed_installation "${version}" ||
    die "${APP_NAME} ${version} is not a managed installation"

  local current=""
  current="$(get_current_version 2>/dev/null || true)"
  if [[ "${current}" == "${version}" ]]; then
    die "${APP_NAME} ${version} is active; switch versions before uninstalling it"
  fi

  require_root_access
  run_as_root rm -rf -- "${target}"
  [[ ! -e "${target}" ]] || die "could not remove ${target}"
  info "Uninstalled ${APP_NAME} ${version}."
}

print_current_version() {
  local current_link="${APP_ROOT}/current"
  if [[ ! -L "${current_link}" ]]; then
    if [[ -e "${current_link}" ]]; then
      die "${current_link} exists and is not a symlink"
    fi
    printf 'none\n'
    return 0
  fi

  local version
  if ! version="$(get_current_version)"; then
    die "${current_link} does not point to a valid version"
  fi

  is_managed_installation "${version}" ||
    die "current points to an invalid or unmanaged ${APP_NAME} installation"
  printf '%s\n' "${version}"
}

list_versions() {
  [[ -d "${APP_ROOT}" ]] || return 0
  require_commands find sort

  local current=""
  current="$(get_current_version 2>/dev/null || true)"
  local version

  while IFS= read -r version; do
    [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
    if is_managed_installation "${version}"; then
      if [[ "${version}" == "${current}" ]]; then
        printf '%s (current)\n' "${version}"
      else
        printf '%s\n' "${version}"
      fi
    else
      printf '%s (unmanaged)\n' "${version}"
    fi
  done < <(find "${APP_ROOT}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V)
}
