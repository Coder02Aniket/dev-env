#!/usr/bin/env bash
# Container entrypoint. Runs as the dev user; sudo is passwordless.

set -euo pipefail

USER_NAME="${USER_NAME:-dev}"
HOME_DIR="/home/${USER_NAME}"

# Re-apply dotfiles on every start so image updates reach an existing home volume.
if [[ -x /usr/local/bin/apply-dotfiles ]]; then
  /usr/local/bin/apply-dotfiles /opt/dotfiles || true
fi

if [[ "${SSH_ENABLED:-1}" == "1" ]]; then
  sudo mkdir -p /run/sshd

  # The host's ~/.ssh is mounted read-only; copy authorized_keys with the
  # ownership sshd expects. Mounting the directory (not the file) avoids Docker
  # creating a directory called authorized_keys when the file does not exist.
  if [[ -f /run/host-ssh/authorized_keys && -s /run/host-ssh/authorized_keys ]]; then
    sudo install -d -m 700 -o "${USER_NAME}" -g "${USER_NAME}" "${HOME_DIR}/.ssh"
    sudo install -m 600 -o "${USER_NAME}" -g "${USER_NAME}" \
      /run/host-ssh/authorized_keys "${HOME_DIR}/.ssh/authorized_keys"
  fi

  sudo /usr/sbin/sshd -p "${SSH_PORT:-2222}"
  echo "sshd listening on ${SSH_PORT:-2222}"
fi

exec "$@"
