#!/usr/bin/env bash
# Print tool versions and service health. Run with: make verify

set -uo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd -- "${ROOT_DIR}/.." && pwd)"
export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${HOME}/.opencode/bin:${HOME}/.azd/bin:${HOME}/.local/share/mise/shims:${PATH}"

have() { command -v "$1" >/dev/null 2>&1; }
missing=0

check() {
  local label="$1" cmd="$2"
  shift 2
  if have "${cmd}"; then
    local out
    out="$("${cmd}" "$@" 2>&1 | head -n 1)"
    printf '  ok    %-10s %s\n' "${label}" "${out:-installed}"
  else
    printf '  MISS  %-10s\n' "${label}"
    missing=$((missing + 1))
  fi
}

optional() {
  local label="$1" cmd="$2"
  shift 2
  if have "${cmd}"; then
    printf '  ok    %-10s %s\n' "${label}" "$("${cmd}" "$@" 2>&1 | head -n 1)"
  else
    printf '  --    %-10s not installed\n' "${label}"
  fi
}

echo "Toolchains"
check git    git    --version
check zsh    zsh    --version
check java   java   -version
check mvn    mvn    -version
check node   node   --version
check bun    bun    --version
check pnpm   pnpm   --version
check python python3 --version
check uv     uv     --version
check gcc    gcc    --version
check cargo  cargo  --version
check rustc  rustc  --version
check go     go     version
check docker docker --version
check compose docker compose version

echo
echo "Cloud and agents"
optional az       az       version
optional azd      azd      version
optional gcloud   gcloud   version
optional kubectl  kubectl  version --client
optional func     func     --version
optional swa      swa      --version
optional azurite  azurite  --version
optional opencode opencode --version
optional starship starship --version
optional chezmoi  chezmoi  --version

echo
echo "Services"
if [[ -f "${REPO_ROOT}/infra/.env" ]]; then
  if have docker; then
    running="$(sudo docker compose -f "${REPO_ROOT}/infra/compose.yaml" --env-file "${REPO_ROOT}/infra/.env" ps -q 2>/dev/null | wc -l)"
    echo "  compose file valid, containers running: ${running}"
  else
    echo "  docker not available"
  fi
else
  echo "  infra/.env missing"
fi

echo
if [[ -f "${ROOT_DIR}/.results.tsv" ]]; then
  echo "Bootstrap steps"
  while IFS=$'\t' read -r name status; do
    printf '  %-16s %s\n' "${name}" "${status}"
  done <"${ROOT_DIR}/.results.tsv"
  echo
fi

if ((missing > 0)); then
  echo "FAIL: ${missing} core tool(s) missing"
  exit 1
fi

echo "PASS: all core tools present"
