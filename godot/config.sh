#!/usr/bin/env bash

readonly APP_NAME="godot"
readonly APP_ROOT="/opt/godot"
readonly APP_EXECUTABLE="godot"
readonly FRONTEND_LINK="/usr/local/bin/godot"
readonly VERSION_EXAMPLE="X.Y.Z or X.Y.Z-stable"

normalize_version() {
  local requested="$1"
  if [[ "${requested}" =~ ^([0-9]+\.[0-9]+\.[0-9]+)(-stable)?$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    return 1
  fi
}
