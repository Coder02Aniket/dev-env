#!/usr/bin/env bash
# opencode CLI. Installed but never authenticated.

set -euo pipefail
: "${ROOT_DIR:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/helpers.sh
. "${ROOT_DIR}/lib/helpers.sh"

export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:${PATH}"
ensure_dir "${HOME}/.local/bin"

if ! has_cmd opencode; then
  log_info "installing opencode"
  curl -fsSL https://opencode.ai/install | bash
else
  log_ok "opencode already installed"
fi

# Normalise the location so the PATH entry in .zshrc always finds it.
for cand in "${HOME}/.opencode/bin/opencode" "${HOME}/.local/bin/opencode"; do
  if [[ -x "${cand}" && "${cand}" != "${HOME}/.local/bin/opencode" ]]; then
    ln -sf "${cand}" "${HOME}/.local/bin/opencode"
    break
  fi
done

if has_cmd opencode; then
  log_ok "opencode ready: $(opencode --version 2>/dev/null || echo installed)"
else
  log_warn "opencode binary not found on PATH after install; open a new shell"
fi

log_info "run 'opencode auth login' once per VM to sign in"
