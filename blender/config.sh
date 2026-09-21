#!/usr/bin/env bash

readonly APP_NAME="blender"
readonly APP_ROOT="/opt/blender"
readonly APP_EXECUTABLE="blender"
readonly FRONTEND_LINK="/usr/local/bin/blender"
readonly VERSION_EXAMPLE="X.Y.Z"

normalize_version() {
  local requested="$1"
  if [[ "${requested}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf '%s\n' "${requested}"
  else
    return 1
  fi
}
