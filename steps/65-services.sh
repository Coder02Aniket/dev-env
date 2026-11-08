#!/usr/bin/env bash
# Prepare the local service stack. Never starts containers.

set -euo pipefail
: "${ROOT_DIR:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/helpers.sh
. "${ROOT_DIR}/lib/helpers.sh"

if [[ "${SKIP_SERVICES:-0}" -eq 1 ]]; then
  log_warn "services skipped (--skip-services)"
  exit 0
fi

INFRA_DIR="${ROOT_DIR}/infra"
ENV_FILE="${INFRA_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  log_info "creating ${ENV_FILE} from .env.example"
  cp "${INFRA_DIR}/.env.example" "${ENV_FILE}"
fi
chmod 600 "${ENV_FILE}"

if ! has_cmd docker; then
  log_warn "docker is not installed yet; skipping compose validation"
  exit 0
fi

log_info "validating compose file"
(cd "${INFRA_DIR}" && sudo docker compose --env-file .env config -q) \
  || die "docker compose config failed"

if [[ "${PULL_IMAGES:-0}" -eq 1 ]]; then
  log_info "pulling service images (no containers started)"
  (cd "${INFRA_DIR}" && sudo docker compose --env-file .env pull)
fi

log_ok "services prepared, not started. Use 'make up' when needed."
