#!/usr/bin/env bash
# Shared helpers. Sourced by bootstrap.sh and the step scripts.

set -euo pipefail

# --- logging ----------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BLUE=$'\033[1;34m'
  C_GREEN=$'\033[1;32m'
  C_YELLOW=$'\033[1;33m'
  C_RED=$'\033[1;31m'
  C_DIM=$'\033[2m'
else
  C_RESET=''; C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_DIM=''
fi

log_step() { printf '\n%s==> %s%s\n' "${C_BLUE}" "$*" "${C_RESET}"; }
log_info() { printf '%s  .. %s%s\n' "${C_DIM}" "$*" "${C_RESET}"; }
log_ok()   { printf '%s  ok %s%s\n' "${C_GREEN}" "$*" "${C_RESET}"; }
log_warn() { printf '%s  !! %s%s\n' "${C_YELLOW}" "$*" "${C_RESET}" >&2; }
die()      { printf '%s  xx %s%s\n' "${C_RED}" "$*" "${C_RESET}" >&2; exit 1; }

# --- guards -----------------------------------------------------------------
require_not_root() {
  [[ "${EUID}" -ne 0 ]] || die "Run as your normal user, not root. sudo is used where needed."
}

require_debian() {
  [[ -r /etc/os-release ]] || die "/etc/os-release missing; unsupported OS"
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}:${ID_LIKE:-}" in
    *debian*|*ubuntu*) : ;;
    *) die "Only Debian/Ubuntu supported (found ${PRETTY_NAME:-unknown})" ;;
  esac
  export DEBIAN_FRONTEND=noninteractive
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

# --- apt --------------------------------------------------------------------
_APT_UPDATED=0

apt_update_once() {
  if [[ "${_APT_UPDATED}" -ne 1 ]]; then
    log_info "apt-get update"
    sudo apt-get update -y
    _APT_UPDATED=1
  fi
}

apt_install() {
  local missing=() pkg
  for pkg in "$@"; do
    dpkg -s "${pkg}" >/dev/null 2>&1 || missing+=("${pkg}")
  done
  if ((${#missing[@]} > 0)); then
    apt_update_once
    log_info "installing: ${missing[*]}"
    sudo apt-get install -y --no-install-recommends "${missing[@]}"
  else
    log_ok "already installed: $*"
  fi
}

apt_install_optional() {
  local missing=() pkg
  for pkg in "$@"; do
    dpkg -s "${pkg}" >/dev/null 2>&1 || missing+=("${pkg}")
  done
  if ((${#missing[@]} > 0)); then
    apt_update_once
    log_info "installing (optional): ${missing[*]}"
    sudo apt-get install -y --no-install-recommends "${missing[@]}" \
      || log_warn "optional packages failed: ${missing[*]}"
  fi
}

# --- installers -------------------------------------------------------------
ensure_mise() {
  export PATH="${HOME}/.local/bin:${PATH}"
  has_cmd mise && return 0
  log_info "installing mise"
  curl -fsSL https://mise.run | sh
  has_cmd mise || die "mise install failed"
}

ensure_chezmoi() {
  export PATH="${HOME}/.local/bin:${PATH}"
  has_cmd chezmoi && return 0
  log_info "installing chezmoi"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "${HOME}/.local/bin"
  has_cmd chezmoi || die "chezmoi install failed"
}

ensure_uv() {
  export PATH="${HOME}/.local/bin:${PATH}"
  has_cmd uv && return 0
  log_info "installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --no-modify-path
  export PATH="${HOME}/.local/bin:${PATH}"
  has_cmd uv || die "uv install failed"
}

# --- misc -------------------------------------------------------------------
ensure_dir() { mkdir -p "$1"; }

record_result() {
  local name="$1" status="$2"
  [[ -n "${RESULTS_FILE:-}" ]] && printf '%s\t%s\n' "${name}" "${status}" >>"${RESULTS_FILE}"
  return 0
}
