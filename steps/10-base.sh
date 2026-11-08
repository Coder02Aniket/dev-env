#!/usr/bin/env bash
# Base packages and quality-of-life CLI tools.

set -euo pipefail
: "${ROOT_DIR:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/helpers.sh
. "${ROOT_DIR}/lib/helpers.sh"

apt_update_once

apt_install \
  build-essential ca-certificates curl wget git unzip zip \
  jq ripgrep fd-find tmux htop tree less vim nano \
  gnupg lsb-release locales man-db bash-completion \
  direnv httpie gh

# Debian/Ubuntu ship fd-find as `fdfind`.
if has_cmd fdfind && ! has_cmd fd; then
  sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
fi

# websocat is not in every release's repos; it is optional.
apt_install_optional websocat

if command -v locale-gen >/dev/null 2>&1; then
  sudo locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
fi

log_ok "base packages ready"
