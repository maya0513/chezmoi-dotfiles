#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=lib/app-manager.sh
source "${SCRIPT_DIR}/../lib/app-manager.sh"
# shellcheck source=godot/config.sh
source "${SCRIPT_DIR}/config.sh"
# shellcheck source=lib/app-doctor.sh
source "${SCRIPT_DIR}/../lib/app-doctor.sh"

readonly -a DOCTOR_REQUIRED_COMMANDS=(
  awk chmod cp curl dirname find jq ln mkdir mktemp mv readlink rm sha512sum sort unzip
)

extract_reported_version() {
  local output="$1"
  if [[ "${output}" =~ ^([0-9]+\.[0-9]+\.[0-9]+)([.]|$) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    return 1
  fi
}

usage() {
  cat <<'EOF'
Usage: godot/doctor.sh [--strict]

Diagnose the local Godot installation without changing it.
With --strict, warnings also result in a non-zero exit status.
EOF
}

strict=0
if (($# > 1)); then
  usage >&2
  exit 2
fi
case "${1:-}" in
  "") ;;
  --strict) strict=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

run_app_doctor "${strict}"
