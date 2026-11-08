#!/usr/bin/env bash
# Apply dotfiles from the repo through chezmoi.

set -euo pipefail
: "${ROOT_DIR:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/helpers.sh
. "${ROOT_DIR}/lib/helpers.sh"

ensure_chezmoi

ensure_dir "${HOME}/.config/chezmoi"
CHEZMOI_CONF="${HOME}/.config/chezmoi/chezmoi.toml"

if [[ ! -f "${CHEZMOI_CONF}" ]]; then
  log_info "writing ${CHEZMOI_CONF}"
  cat >"${CHEZMOI_CONF}" <<'EOF'
[data]
  name = "Aniket Shankar Nangare"
  email = "aniketnangare87@gmail.com"
EOF
fi

log_info "applying dotfiles from ${ROOT_DIR}/dotfiles"
chezmoi --source "${ROOT_DIR}/dotfiles" apply --force

log_ok "dotfiles applied"
