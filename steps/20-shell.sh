#!/usr/bin/env bash
# zsh as the default shell, plus starship and shell plugins.

set -euo pipefail
: "${ROOT_DIR:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/helpers.sh
. "${ROOT_DIR}/lib/helpers.sh"

apt_install zsh
apt_install_optional zsh-autosuggestions zsh-syntax-highlighting

export PATH="${HOME}/.local/bin:${PATH}"

if ! has_cmd starship && [[ ! -x "${HOME}/.local/bin/starship" ]]; then
  log_info "installing starship"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y --bin-dir "${HOME}/.local/bin"
else
  log_ok "starship already installed"
fi

ZSH_BIN="$(command -v zsh)"
CURRENT_SHELL="$(getent passwd "${RUN_USER}" | cut -d: -f7)"
if [[ "${CURRENT_SHELL}" != "${ZSH_BIN}" ]]; then
  log_info "setting login shell to zsh for ${RUN_USER}"
  sudo chsh -s "${ZSH_BIN}" "${RUN_USER}"
else
  log_ok "login shell already zsh"
fi

log_ok "shell ready"
