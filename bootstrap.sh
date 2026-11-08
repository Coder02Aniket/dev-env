#!/usr/bin/env bash
# Dev-env bootstrap. Idempotent setup for Ubuntu/Debian VMs.
#
# Usage:
#   ./bootstrap.sh [--pull-images] [--skip-services] [--only <step>] [--with-secrets <file>]
#
# Every step is safe to run more than once. A failed run can be resumed by
# running the script again after fixing the cause.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR

# shellcheck source=lib/helpers.sh
. "${ROOT_DIR}/lib/helpers.sh"

PULL_IMAGES=0
SKIP_SERVICES=0
ONLY=""
WITH_SECRETS=""

while (($#)); do
  case "$1" in
    --pull-images)  PULL_IMAGES=1; shift ;;
    --skip-services) SKIP_SERVICES=1; shift ;;
    --only)         ONLY="${2:?--only needs a step name}"; shift 2 ;;
    --with-secrets) WITH_SECRETS="${2:?--with-secrets needs a key file}"; shift 2 ;;
    -h|--help)
      sed -n '3,8p' "$0"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

export PULL_IMAGES SKIP_SERVICES WITH_SECRETS

require_not_root
require_debian

RUN_USER="${SUDO_USER:-$USER}"
export RUN_USER

RESULTS_FILE="${ROOT_DIR}/.results.tsv"
export RESULTS_FILE
: >"${RESULTS_FILE}"

log_step "dev-env bootstrap"
log_info "repo: ${ROOT_DIR}"
log_info "user: ${RUN_USER}"
log_info "os:   ${PRETTY_NAME:-unknown}"

if [[ -n "${WITH_SECRETS}" ]]; then
  log_warn "--with-secrets is reserved for the future age bundle; ignoring for now"
fi

mapfile -t steps < <(find "${ROOT_DIR}/steps" -maxdepth 1 -type f -name '[0-9][0-9]-*.sh' | sort)
((${#steps[@]} > 0)) || die "no step scripts found in ${ROOT_DIR}/steps"

if [[ -n "${ONLY}" ]]; then
  filtered=()
  for f in "${steps[@]}"; do
    [[ "$(basename "${f}")" == *"${ONLY}"* ]] && filtered+=("${f}")
  done
  ((${#filtered[@]} > 0)) || die "no step matches --only '${ONLY}'"
  steps=("${filtered[@]}")
fi

for step in "${steps[@]}"; do
  name="$(basename "${step}" .sh)"
  log_step "${name}"
  if bash "${step}"; then
    record_result "${name}" ok
    log_ok "${name}"
  else
    record_result "${name}" FAILED
    die "${name} failed. Fix the cause and re-run; completed steps are skipped."
  fi
done

log_step "done"
log_info "step results: ${RESULTS_FILE}"
log_info "run 'make verify' to print versions"
if ! id -nG "${RUN_USER}" | grep -qw docker; then
  log_warn "log out and back in (or run: newgrp docker) before using docker"
fi
