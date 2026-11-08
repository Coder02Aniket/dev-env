#!/usr/bin/env bash
# Docker Engine from the official repository, with compose and buildx.

set -euo pipefail
: "${ROOT_DIR:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/helpers.sh
. "${ROOT_DIR}/lib/helpers.sh"

# shellcheck disable=SC1091
. /etc/os-release
DISTRO="ubuntu"
[[ "${ID}" == "debian" ]] && DISTRO="debian"
CODENAME="${VERSION_CODENAME:-noble}"

sudo install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  log_info "adding Docker apt key"
  curl -fsSL "https://download.docker.com/linux/${DISTRO}/gpg" \
    | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
  log_info "adding Docker apt repo"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO} ${CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
fi

apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker

if ! id -nG "${RUN_USER}" | grep -qw docker; then
  log_info "adding ${RUN_USER} to the docker group"
  sudo usermod -aG docker "${RUN_USER}"
fi

log_ok "docker ready: $(sudo docker --version)"
log_warn "group change applies to new sessions: log out/in or run 'newgrp docker'"
