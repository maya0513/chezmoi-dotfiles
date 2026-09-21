#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=lib/app-manager.sh
source "${SCRIPT_DIR}/../lib/app-manager.sh"
# shellcheck source=godot/config.sh
source "${SCRIPT_DIR}/config.sh"

(($# == 0)) || die "current.sh does not accept arguments"
require_commands readlink
print_current_version
