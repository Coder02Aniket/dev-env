#!/usr/bin/env bash
# Google Cloud CLI, GKE auth plugin, and kubectl.

set -euo pipefail
: "${ROOT_DIR:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/helpers.sh
. "${ROOT_DIR}/lib/helpers.sh"

apt_install apt-transport-https ca-certificates gnupg curl

sudo install -m 0755 -d /usr/share/keyrings

if [[ ! -f /usr/share/keyrings/cloud.google.gpg ]]; then
  log_info "adding Google Cloud apt key"
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | sudo gpg --dearmor --yes -o /usr/share/keyrings/cloud.google.gpg
  sudo chmod a+r /usr/share/keyrings/cloud.google.gpg
fi

if [[ ! -f /etc/apt/sources.list.d/google-cloud-sdk.list ]]; then
  log_info "adding Google Cloud apt repo"
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
  sudo apt-get update -y
fi

apt_install google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin kubectl

log_ok "gcloud ready: $(gcloud version 2>/dev/null | head -n 1)"
log_info "run 'gcloud auth login' once per VM"
