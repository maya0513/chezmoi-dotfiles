#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=lib/app-manager.sh
source "${SCRIPT_DIR}/../lib/app-manager.sh"
# shellcheck source=godot/config.sh
source "${SCRIPT_DIR}/config.sh"

if (($# != 1)) || [[ "$1" == "-h" || "$1" == "--help" ]]; then
  printf 'Usage: godot/use.sh VERSION\n'
  (($# == 1)) && exit 0 || exit 2
fi

require_commands readlink dirname uname
require_linux_x86_64
activate_version "$(canonical_version "$1")"
