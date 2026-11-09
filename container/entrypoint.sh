#!/usr/bin/env bash
# Container entrypoint. Runs as the dev user; sudo is passwordless.

set -euo pipefail

USER_NAME="${USER_NAME:-dev}"
HOME_DIR="/home/${USER_NAME}"

# Re-apply dotfiles on every start so image updates reach an existing home volume.
if [[ -d /opt/dotfiles ]] && command -v chezmoi >/dev/null 2>&1; then
  chezmoi --source /opt/dotfiles apply --force || true
fi

if [[ "${SSH_ENABLED:-1}" == "1" ]]; then
  sudo mkdir -p /run/sshd

  # The host mounts its authorized_keys read-only here; copy it with the
  # ownership sshd expects. The -f check matters: if the host file is missing,
  # Docker creates a directory at the mount point instead.
  if [[ -f /run/host-authorized-keys && -s /run/host-authorized-keys ]]; then
    sudo install -d -m 700 -o "${USER_NAME}" -g "${USER_NAME}" "${HOME_DIR}/.ssh"
    sudo install -m 600 -o "${USER_NAME}" -g "${USER_NAME}" \
      /run/host-authorized-keys "${HOME_DIR}/.ssh/authorized_keys"
  fi

  sudo /usr/sbin/sshd -p "${SSH_PORT:-2222}"
  echo "sshd listening on ${SSH_PORT:-2222}"
fi

exec "$@"
