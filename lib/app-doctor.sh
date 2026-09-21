#!/usr/bin/env bash

# Read-only diagnostics shared by the Godot and Blender doctor scripts.
# The caller must define APP_NAME, APP_ROOT, APP_EXECUTABLE, FRONTEND_LINK,
# DOCTOR_REQUIRED_COMMANDS, and extract_reported_version. The lifecycle helpers
# from app-manager.sh must also be loaded first.

DOCTOR_ERRORS=0
DOCTOR_WARNINGS=0
DOCTOR_MANAGED_COUNT=0
DOCTOR_CURRENT_VERSION=""
DOCTOR_CURRENT_VALID=0
DOCTOR_FRONTEND_VALID=0

doctor_ok() {
  printf '[OK] %s\n' "$*"
}

doctor_info() {
  printf '[INFO] %s\n' "$*"
}

doctor_warn() {
  printf '[WARN] %s\n' "$*"
  DOCTOR_WARNINGS=$((DOCTOR_WARNINGS + 1))
}

doctor_error() {
  printf '[ERROR] %s\n' "$*"
  DOCTOR_ERRORS=$((DOCTOR_ERRORS + 1))
}

doctor_check_platform() {
  if ! command -v uname >/dev/null 2>&1; then
    doctor_error "cannot inspect the platform because uname is missing"
    return
  fi

  local system architecture
  system="$(uname -s)"
  architecture="$(uname -m)"
  if [[ "${system}" == "Linux" && "${architecture}" == "x86_64" ]]; then
    doctor_ok "platform: Linux x86_64"
  else
    doctor_error "unsupported platform: ${system} ${architecture}; expected Linux x86_64"
  fi
}

doctor_check_required_commands() {
  local command_name
  local -a missing=()

  for command_name in "${DOCTOR_REQUIRED_COMMANDS[@]}"; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
      missing+=("${command_name}")
    fi
  done

  if ((EUID != 0)) && ! command -v sudo >/dev/null 2>&1; then
    missing+=("sudo")
  fi

  if ((${#missing[@]} == 0)); then
    doctor_ok "required commands are available"
  else
    doctor_error "required commands are missing: ${missing[*]}"
  fi
}

doctor_check_version_directory() {
  local version="$1"
  local target
  target="$(version_path "${version}")"
  local marker="${target}/.managed-by-chezmoi-dotfiles"
  local valid=1

  if [[ -L "${target}" ]]; then
    doctor_error "version path must not be a symlink: ${target}"
    return
  fi
  if [[ ! -d "${target}" ]]; then
    doctor_error "version path is not a directory: ${target}"
    return
  fi

  if [[ ! -f "${marker}" ]]; then
    doctor_error "management marker is missing: ${marker}"
    valid=0
  elif [[ ! -r "${marker}" ]]; then
    doctor_error "management marker is not readable: ${marker}"
    valid=0
  else
    local marker_value
    marker_value="$(<"${marker}")"
    if [[ "${marker_value}" != "${APP_NAME} ${version}" ]]; then
      doctor_error "management marker has unexpected content: ${marker}"
      valid=0
    fi
  fi

  if [[ ! -e "${target}/${APP_EXECUTABLE}" ]]; then
    doctor_error "executable is missing: ${target}/${APP_EXECUTABLE}"
    valid=0
  elif [[ ! -f "${target}/${APP_EXECUTABLE}" ]]; then
    doctor_error "executable is not a regular file: ${target}/${APP_EXECUTABLE}"
    valid=0
  elif [[ ! -x "${target}/${APP_EXECUTABLE}" ]]; then
    doctor_error "executable bit is missing: ${target}/${APP_EXECUTABLE}"
    valid=0
  fi

  if ((valid)); then
    DOCTOR_MANAGED_COUNT=$((DOCTOR_MANAGED_COUNT + 1))
    doctor_ok "managed installation: ${version}"
  fi
}

doctor_check_installations() {
  if [[ ! -e "${APP_ROOT}" ]]; then
    doctor_warn "installation root does not exist: ${APP_ROOT}"
    return
  fi
  if [[ ! -d "${APP_ROOT}" ]]; then
    doctor_error "installation root is not a directory: ${APP_ROOT}"
    return
  fi
  if [[ ! -r "${APP_ROOT}" || ! -x "${APP_ROOT}" ]]; then
    doctor_error "installation root is not readable: ${APP_ROOT}"
    return
  fi

  doctor_ok "installation root: ${APP_ROOT}"

  local target name
  local version_entry_count=0
  for target in "${APP_ROOT}"/*; do
    [[ -e "${target}" || -L "${target}" ]] || continue
    name="${target##*/}"
    [[ "${name}" == "current" ]] && continue

    if [[ "${name}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      version_entry_count=$((version_entry_count + 1))
      doctor_check_version_directory "${name}"
    else
      doctor_warn "unexpected entry in installation root: ${target}"
    fi
  done

  if ((version_entry_count == 0)); then
    doctor_warn "no installed ${APP_NAME} versions were found"
  fi
}

doctor_check_current() {
  local current_link="${APP_ROOT}/current"

  if [[ ! -L "${current_link}" ]]; then
    if [[ -e "${current_link}" ]]; then
      doctor_error "current path exists but is not a symlink: ${current_link}"
    elif ((DOCTOR_MANAGED_COUNT > 0)); then
      doctor_error "current symlink is missing: ${current_link}"
    else
      doctor_info "active version is not configured"
    fi
    return
  fi

  if ! command -v readlink >/dev/null 2>&1; then
    doctor_error "cannot inspect ${current_link} because readlink is missing"
    return
  fi

  local version
  if ! version="$(readlink "${current_link}")"; then
    doctor_error "could not read current symlink: ${current_link}"
    return
  fi
  if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    doctor_error "current symlink has an invalid destination: ${current_link} -> ${version}"
    return
  fi
  if ! is_managed_installation "${version}"; then
    doctor_error "current points to an invalid or unmanaged installation: ${version}"
    return
  fi

  DOCTOR_CURRENT_VERSION="${version}"
  DOCTOR_CURRENT_VALID=1
  doctor_ok "current: ${version}"
}

doctor_check_frontend() {
  local expected_destination="${APP_ROOT}/current/${APP_EXECUTABLE}"

  if [[ ! -L "${FRONTEND_LINK}" ]]; then
    if [[ -e "${FRONTEND_LINK}" ]]; then
      doctor_error "frontend exists but is not a symlink: ${FRONTEND_LINK}"
    elif ((DOCTOR_CURRENT_VALID)); then
      doctor_error "frontend symlink is missing: ${FRONTEND_LINK}"
    else
      doctor_info "frontend is not configured: ${FRONTEND_LINK}"
    fi
    return
  fi

  if ! command -v readlink >/dev/null 2>&1; then
    doctor_error "cannot inspect ${FRONTEND_LINK} because readlink is missing"
    return
  fi

  local actual_destination
  if ! actual_destination="$(readlink "${FRONTEND_LINK}")"; then
    doctor_error "could not read frontend symlink: ${FRONTEND_LINK}"
    return
  fi
  if [[ "${actual_destination}" != "${expected_destination}" ]]; then
    doctor_error "frontend points to an unmanaged destination: ${FRONTEND_LINK} -> ${actual_destination}"
    return
  fi
  if [[ ! -x "${FRONTEND_LINK}" ]]; then
    doctor_error "frontend does not resolve to an executable: ${FRONTEND_LINK}"
    return
  fi

  DOCTOR_FRONTEND_VALID=1
  doctor_ok "frontend: ${FRONTEND_LINK} -> ${actual_destination}"
}

doctor_check_path() {
  local resolved=""
  resolved="$(command -v "${APP_EXECUTABLE}" 2>/dev/null || true)"

  if [[ -z "${resolved}" ]]; then
    if ((DOCTOR_CURRENT_VALID)); then
      doctor_error "${APP_EXECUTABLE} is not available on PATH"
    else
      doctor_info "${APP_EXECUTABLE} is not available on PATH"
    fi
    return
  fi

  if [[ "${resolved}" == "${FRONTEND_LINK}" ]]; then
    doctor_ok "PATH resolves to ${resolved}"
  elif ((DOCTOR_CURRENT_VALID)); then
    doctor_error "PATH resolves ${APP_EXECUTABLE} to ${resolved}; expected ${FRONTEND_LINK}"
  else
    doctor_info "PATH resolves ${APP_EXECUTABLE} to unmanaged command ${resolved}"
  fi

  local candidate
  local -A seen=()
  while IFS= read -r candidate; do
    [[ -n "${candidate}" ]] || continue
    [[ -n "${seen[${candidate}]:-}" ]] && continue
    seen["${candidate}"]=1
    if [[ "${candidate}" != "${resolved}" ]]; then
      doctor_info "additional executable on PATH: ${candidate}"
    fi
  done < <(type -aP "${APP_EXECUTABLE}" 2>/dev/null || true)
}

doctor_check_reported_version() {
  ((DOCTOR_CURRENT_VALID && DOCTOR_FRONTEND_VALID)) || return

  local output
  if ! output="$("${FRONTEND_LINK}" --version 2>&1)"; then
    doctor_error "could not run ${FRONTEND_LINK} --version"
    return
  fi

  local reported
  if ! reported="$(extract_reported_version "${output}")"; then
    doctor_error "could not parse the version reported by ${FRONTEND_LINK}"
    return
  fi
  if [[ "${reported}" != "${DOCTOR_CURRENT_VERSION}" ]]; then
    doctor_error "executable reports ${reported}; current points to ${DOCTOR_CURRENT_VERSION}"
    return
  fi

  doctor_ok "executable reports ${reported}"
}

doctor_check_staging_files() {
  local frontend_dir="${FRONTEND_LINK%/*}"
  local candidate
  local found=0

  for candidate in \
    "${APP_ROOT}"/.install-*.tmp \
    "${APP_ROOT}"/.current.*.tmp \
    "${frontend_dir}"/."${APP_NAME}".*.tmp; do
    [[ -e "${candidate}" || -L "${candidate}" ]] || continue
    found=1
    doctor_warn "stale staging entry: ${candidate}"
  done

  if ((found == 0)); then
    doctor_ok "no stale staging entries"
  fi
}

run_app_doctor() {
  local strict="$1"

  printf '%s doctor\n\n' "${APP_NAME^}"
  doctor_check_platform
  doctor_check_required_commands
  doctor_check_installations
  doctor_check_current
  doctor_check_frontend
  doctor_check_path
  doctor_check_reported_version
  doctor_check_staging_files

  printf '\nResult: '
  if ((DOCTOR_ERRORS > 0)); then
    printf 'unhealthy (%d error(s), %d warning(s))\n' "${DOCTOR_ERRORS}" "${DOCTOR_WARNINGS}"
    return 1
  fi
  if ((DOCTOR_WARNINGS > 0)); then
    printf 'healthy with warnings (0 errors, %d warning(s))\n' "${DOCTOR_WARNINGS}"
    ((strict == 0)) || return 1
    return 0
  fi

  printf 'healthy (0 errors, 0 warnings)\n'
}
