#!/usr/bin/env bash
# C/C++ toolchain for native work and embedded experiments.

set -euo pipefail
: "${ROOT_DIR:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/helpers.sh
. "${ROOT_DIR}/lib/helpers.sh"

apt_install gcc g++ clang cmake make gdb valgrind pkg-config

log_ok "native toolchain ready: $(gcc --version | head -n 1)"
