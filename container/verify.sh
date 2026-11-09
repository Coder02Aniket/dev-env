#!/usr/bin/env bash
# Tool and service report for the inside of the dev container.

set -uo pipefail

have() { command -v "$1" >/dev/null 2>&1; }
missing=0

check() {
  local label="$1" cmd="$2"
  shift 2
  if have "${cmd}"; then
    printf '  ok    %-10s %s\n' "${label}" "$("${cmd}" "$@" 2>&1 | head -n 1)"
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
optional gh       gh       --version
optional starship starship --version
optional chezmoi  chezmoi  --version

echo
echo "Services"
if [[ -f /opt/dev-env/infra/compose.yaml ]]; then
  if docker info >/dev/null 2>&1; then
    running="$(docker compose -f /opt/dev-env/infra/compose.yaml --env-file /opt/dev-env/infra/.env ps -q 2>/dev/null | wc -l)"
    echo "  containers running: ${running}"
  else
    echo "  docker socket not accessible"
  fi
else
  echo "  repo not mounted at /opt/dev-env"
fi

echo
if ((missing > 0)); then
  echo "FAIL: ${missing} core tool(s) missing"
  exit 1
fi

echo "PASS: all core tools present"
