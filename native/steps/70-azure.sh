#!/usr/bin/env bash
# Azure CLI, azd, Functions Core Tools, SWA CLI, Azurite.

set -euo pipefail
: "${ROOT_DIR:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/helpers.sh
. "${ROOT_DIR}/lib/helpers.sh"

export PATH="${HOME}/.local/bin:${PATH}"

if ! has_cmd az; then
  log_info "installing Azure CLI"
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
else
  log_ok "az already installed"
fi

if ! has_cmd azd; then
  log_info "installing Azure Developer CLI"
  curl -fsSL https://aka.ms/install-azd.sh | bash
fi
for cand in "${HOME}/.azd/bin/azd" /usr/local/bin/azd; do
  if [[ -x "${cand}" ]]; then
    ln -sf "${cand}" "${HOME}/.local/bin/azd"
    break
  fi
done

# Node-based Azure tools go into the mise-managed Node install.
if has_cmd mise; then
  log_info "installing Functions Core Tools, SWA CLI, Azurite"
  mise exec -- npm install -g \
    azure-functions-core-tools@4 \
    @azure/static-web-apps-cli \
    azurite
else
  log_warn "mise not found; skipping npm-based Azure tools"
fi

log_ok "azure tooling ready"
