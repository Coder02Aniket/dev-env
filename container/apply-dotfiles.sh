#!/usr/bin/env bash
# Apply the chezmoi-style dotfiles in this repo without requiring chezmoi.
#
# Source layout:
#   dot_zshrc          -> ~/.zshrc
#   dot_tmux.conf      -> ~/.tmux.conf
#   dot_gitconfig.tmpl -> ~/.gitconfig (name and email substituted)
#   dot_config/*       -> ~/.config/*
#
# This runs both at image build time and on every container start, so an
# existing dev-home volume picks up dotfile changes from a new image.

set -euo pipefail

SRC="${1:-/opt/dotfiles}"
DEST="${HOME:?HOME is not set}"
NAME="${DEV_NAME:-Aniket Shankar Nangare}"
EMAIL="${DEV_EMAIL:-aniketnangare87@gmail.com}"

[[ -d "${SRC}" ]] || { echo "dotfiles source ${SRC} not found" >&2; exit 1; }

install -m 0644 "${SRC}/dot_zshrc" "${DEST}/.zshrc"
install -m 0644 "${SRC}/dot_tmux.conf" "${DEST}/.tmux.conf"

# The template is `name = {{ .name | quote }}`; drop the quotes and the pipe
# expression, keep the surrounding TOML/INI quoting.
sed -e "s#{{ *\.name *| *quote * }}#\"${NAME}\"#" \
    -e "s#{{ *\.email *| *quote * }}#\"${EMAIL}\"#" \
    "${SRC}/dot_gitconfig.tmpl" > "${DEST}/.gitconfig"
chmod 0644 "${DEST}/.gitconfig"

if [[ -d "${SRC}/dot_config" ]]; then
  install -d -m 0755 "${DEST}/.config"
  for file in "${SRC}/dot_config"/*; do
    [[ -f "${file}" ]] || continue
    install -m 0644 "${file}" "${DEST}/.config/$(basename "${file}")"
  done
fi
