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

install_docker_dnf() {
  local major pattern baseurl
  major="$(. /etc/os-release && echo "${VERSION_ID%%.*}")"
  [[ -n "${major}" ]] || die "cannot determine major version from /etc/os-release"

  # Rocky reports $releasever as a minor version (9.6), but Docker only
  # publishes major-version paths (/centos/9). Download the repo file and pin
  # it, which also avoids dnf4/dnf5 config-manager differences.
  baseurl="https://download.docker.com/linux/centos/${major}/x86_64/stable"
  curl -fsSL --max-time 30 "${baseurl}/repodata/repomd.xml" >/dev/null ||
    die "Docker has no package repository for EL ${major} (${baseurl}). Use an EL9/EL10 VM or Podman."

  log "configuring Docker's RPM repository (centos/${major})"
  curl -fsSL --max-time 30 https://download.docker.com/linux/centos/docker-ce.repo -o /tmp/docker-ce.repo
  sudo install -m 0644 /tmp/docker-ce.repo /etc/yum.repos.d/docker-ce.repo
  pattern='s|\$releasever|'"${major}"'|g'
  sudo sed -i "$pattern" /etc/yum.repos.d/docker-ce.repo
  rm -f /tmp/docker-ce.repo

  sudo dnf install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
}

if ! have docker; then
  log "installing Docker"
  case "${ID:-}" in
    # Docker publishes RHEL-compatible packages under /linux/centos, but only
    # per major version. Fedora has its own path, so it uses get.docker.com.
    rocky|almalinux|rhel|centos)
      install_docker_dnf || die "Docker CE install failed for this EL version. Use an EL9/EL10 VM or Podman."
      ;;
    *)
      if ! curl -fsSL https://get.docker.com | sudo sh; then
        die "Docker install failed. On very new releases, install Docker CE manually or use Podman."
      fi
      ;;
  esac
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

PULL_OUTPUT=""
pull_dev() {
  local out
  if out="$("${COMPOSE[@]}" pull dev 2>&1)"; then
    return 0
  fi
  PULL_OUTPUT="${out}"
  return 1
}

if [[ "${DEV_ENV_FORCE_BUILD:-0}" == "1" ]]; then
  log "DEV_ENV_FORCE_BUILD=1, building locally"
  "${COMPOSE[@]}" up -d --build
elif [[ "${USER_UID}" != "1000" || "${USER_GID}" != "1000" ]]; then
  # The published image bakes USER_UID/USER_GID into /etc/passwd so the
  # container user owns the bind-mounted workspace. Any other ID cannot use it
  # and needs an image built for this account.
  log "host account is ${USER_UID}:${USER_GID}; the published image is built for 1000:1000"
  log "building a local image to match your account (one time per host)"
  "${COMPOSE[@]}" up -d --build
elif pull_dev; then
  log "using the published image"
  "${COMPOSE[@]}" up -d
else
  log "could not pull the published image; building locally"
  printf '%s\n' "${PULL_OUTPUT}" | tail -n 6 | sed 's/^/    /'
  "${COMPOSE[@]}" up -d --build
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
