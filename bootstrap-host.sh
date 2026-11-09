#!/usr/bin/env bash
# Host bootstrap. Supports Ubuntu, Debian, Rocky, Alma, RHEL, CentOS, Fedora.
# Everything except Docker and git/curl runs inside the container.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${REPO_ROOT}"

log()  { printf '\n==> %s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

[[ "${EUID}" -ne 0 ]] || die "run as a normal user, not root"
[[ -r /etc/os-release ]] || die "unsupported OS: /etc/os-release missing"
# shellcheck disable=SC1091
. /etc/os-release

case "${ID:-}" in
  ubuntu|debian|rocky|almalinux|rhel|centos|fedora) : ;;
  *) die "unsupported distro: ${PRETTY_NAME:-unknown}" ;;
esac

if ! have git || ! have curl; then
  log "installing git and curl"
  if have apt-get; then
    sudo apt-get update && sudo apt-get install -y git curl ca-certificates
  elif have dnf; then
    sudo dnf install -y git curl ca-certificates
  else
    die "no supported package manager found"
  fi
fi

if ! have docker; then
  log "installing Docker"
  if ! curl -fsSL https://get.docker.com | sudo sh; then
    die "Docker install failed. On very new releases, install Docker CE manually or use Podman."
  fi
fi

if have systemctl; then
  sudo systemctl enable --now docker || true
fi

NEED_RELOGIN=0
if ! id -nG "${USER}" | grep -qw docker; then
  log "adding ${USER} to the docker group"
  sudo usermod -aG docker "${USER}"
  NEED_RELOGIN=1
fi

# Match the container user to the host account so bind-mounted files are owned
# correctly.
USER_UID="$(id -u)"
USER_GID="$(id -g)"
export USER_UID USER_GID

WORKSPACE_DIR="${WORKSPACE_DIR:-${HOME}/projects}"
export WORKSPACE_DIR
mkdir -p "${WORKSPACE_DIR}"
mkdir -p "${HOME}/.ssh"
touch "${HOME}/.ssh/authorized_keys"
chmod 700 "${HOME}/.ssh"
chmod 600 "${HOME}/.ssh/authorized_keys"

[[ -f infra/.env ]] || cp infra/.env.example infra/.env

DOCKER_GID="$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo 999)"
export DOCKER_GID

# After usermod, this shell is not in the docker group yet, so fall back to
# sudo. Preserve the variables compose needs, or the mounts resolve against
# /root instead of your home.
if docker info >/dev/null 2>&1; then
  COMPOSE=(docker compose -f docker-compose.dev.yaml)
else
  COMPOSE=(sudo --preserve-env=HOME,WORKSPACE_DIR,DOCKER_GID,USER_UID,USER_GID \
           docker compose -f docker-compose.dev.yaml)
fi

log "starting the dev container"

if [[ "${USER_UID}" != "1000" ]]; then
  # A published image is built for UID 1000; rebuild for other host IDs.
  "${COMPOSE[@]}" up -d --build
elif ! "${COMPOSE[@]}" pull dev 2>/dev/null; then
  log "published image unavailable, building locally (first build takes several minutes)"
  "${COMPOSE[@]}" up -d --build
else
  "${COMPOSE[@]}" up -d
fi

log "done"
echo "  enter:     docker exec -it dev zsh"
echo "  ssh:       ssh -p 2222 dev@<vm-ip>"
echo "  verify:    make verify"
echo "  services:  make services-up S=postgres"
echo "  rebuild:   make rebuild"
if [[ "${NEED_RELOGIN}" -eq 1 ]]; then
  echo
  echo "  note: log out and back in so your user picks up docker group access"
fi
