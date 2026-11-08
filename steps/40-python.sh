#!/usr/bin/env bash
# Python 3.12 via uv, plus pipx for isolated global CLIs.

set -euo pipefail
: "${ROOT_DIR:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/helpers.sh
. "${ROOT_DIR}/lib/helpers.sh"

apt_install python3 python3-venv python3-dev python3-pip pipx

ensure_uv
export PATH="${HOME}/.local/bin:${PATH}"

log_info "installing Python 3.12 via uv"
uv python install 3.12

log_ok "python ready: $(uv python find 3.12 2>/dev/null || echo 'see uv python list')"
