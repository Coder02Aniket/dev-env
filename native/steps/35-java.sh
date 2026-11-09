#!/usr/bin/env bash
# JDK 21 LTS (default) and JDK 17, plus Maven 3.9.

set -euo pipefail
: "${ROOT_DIR:=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/helpers.sh
. "${ROOT_DIR}/lib/helpers.sh"

# shellcheck disable=SC1091
. /etc/os-release
CODENAME="${VERSION_CODENAME:-noble}"

sudo install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/adoptium.asc ]]; then
  log_info "adding Adoptium apt key"
  wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public \
    | sudo tee /etc/apt/keyrings/adoptium.asc >/dev/null
  sudo chmod a+r /etc/apt/keyrings/adoptium.asc
fi

if [[ ! -f /etc/apt/sources.list.d/adoptium.list ]]; then
  log_info "adding Adoptium apt repo"
  echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb ${CODENAME} main" \
    | sudo tee /etc/apt/sources.list.d/adoptium.list >/dev/null
  sudo apt-get update -y
fi

apt_install temurin-21-jdk
apt_install_optional temurin-17-jdk

# Make 21 the default when both are present.
if [[ -d /usr/lib/jvm/temurin-21-jdk-amd64 ]]; then
  for bin in java javac jar; do
    if [[ -x "/usr/lib/jvm/temurin-21-jdk-amd64/bin/${bin}" ]]; then
      sudo update-alternatives --set "${bin}" "/usr/lib/jvm/temurin-21-jdk-amd64/bin/${bin}" >/dev/null 2>&1 || true
    fi
  done
fi

MAVEN_VERSION="3.9.9"
if ! has_cmd mvn; then
  log_info "installing Maven ${MAVEN_VERSION}"
  tmp="$(mktemp -d)"
  curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
    -o "${tmp}/maven.tgz"
  sudo tar -xzf "${tmp}/maven.tgz" -C /opt
  sudo ln -sfn "/opt/apache-maven-${MAVEN_VERSION}" /opt/maven
  sudo ln -sfn /opt/maven/bin/mvn /usr/local/bin/mvn
  rm -rf "${tmp}"
else
  log_ok "maven already installed"
fi

java -version 2>&1 | head -n 1
log_ok "java ready"
