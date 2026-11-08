#!/usr/bin/env bash
# Node 22 LTS and Bun via mise, plus pnpm.

set -euo pipefail
: "${ROOT_DIR:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/helpers.sh
. "${ROOT_DIR}/lib/helpers.sh"

ensure_mise
export PATH="${HOME}/.local/bin:${PATH}"
export MISE_YES=1

ensure_dir "${HOME}/.config/mise"
MISE_CONF="${HOME}/.config/mise/config.toml"
if [[ ! -f "${MISE_CONF}" ]]; then
  log_info "writing ${MISE_CONF}"
  cp "${ROOT_DIR}/versions/mise.toml" "${MISE_CONF}"
fi

log_info "installing runtimes from mise config"
mise install

if ! mise exec -- pnpm --version >/dev/null 2>&1; then
  log_info "installing pnpm"
  mise exec -- npm install -g pnpm
fi

mise exec -- node --version
log_ok "bun $(mise exec -- bun --version)"
log_ok "node ready"
