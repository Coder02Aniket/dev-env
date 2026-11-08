#!/usr/bin/env bash
# Rust via rustup and Go via mise.

set -euo pipefail
: "${ROOT_DIR:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/helpers.sh
. "${ROOT_DIR}/lib/helpers.sh"

export PATH="${HOME}/.cargo/bin:${HOME}/.local/bin:${PATH}"

if ! has_cmd rustup; then
  log_info "installing rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --profile minimal
else
  log_ok "rustup already installed"
fi

ensure_mise
ensure_dir "${HOME}/.config/mise"
MISE_CONF="${HOME}/.config/mise/config.toml"
if [[ ! -f "${MISE_CONF}" ]]; then
  cp "${ROOT_DIR}/versions/mise.toml" "${MISE_CONF}"
fi
mise install

log_ok "rust: $(rustc --version 2>/dev/null || echo 'open a new shell')"
log_ok "go:   $(mise exec -- go version 2>/dev/null || echo 'see mise install')"
