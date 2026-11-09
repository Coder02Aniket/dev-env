# syntax=docker/dockerfile:1.7
# Container-first development environment.
# Base is pinned to Ubuntu 24.04 so every host distro gets the same userspace.

FROM ubuntu:24.04

ARG USER_NAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
ARG MAVEN_VERSION=3.9.9

# bash + pipefail for every RUN, and a retry helper for the GitHub-hosted
# installers, which occasionally answer with 5xx.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY container/retry.sh /usr/local/bin/retry
RUN chmod 0755 /usr/local/bin/retry

LABEL org.opencontainers.image.source="https://github.com/Coder02Aniket/dev-env"
LABEL org.opencontainers.image.description="Portable Ubuntu-based development environment"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    MISE_YES=1

# --- base packages ----------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget git gnupg lsb-release sudo locales tzdata \
      build-essential clang cmake gdb valgrind pkg-config make \
      unzip zip jq ripgrep fd-find tmux htop tree vim nano \
      less man-db bash-completion zsh zsh-autosuggestions zsh-syntax-highlighting \
      direnv httpie gh openssh-server \
      iproute2 procps net-tools dnsutils iputils-ping socat libsecret-1-0 \
      python3 python3-venv python3-dev python3-pip pipx \
    && locale-gen en_US.UTF-8 \
    && ln -sf "$(command -v fdfind)" /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# --- user -------------------------------------------------------------------
# The Ubuntu base ships an `ubuntu` user at UID/GID 1000; remove it so the
# configured user can take that ID and match the host account.
RUN userdel -r ubuntu 2>/dev/null || true; \
    groupdel ubuntu 2>/dev/null || true; \
    groupadd --gid "${USER_GID}" "${USER_NAME}"; \
    useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/zsh "${USER_NAME}"; \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-${USER_NAME}"; \
    chmod 0440 "/etc/sudoers.d/90-${USER_NAME}"

# --- Java -------------------------------------------------------------------
RUN install -d /etc/apt/keyrings \
    && wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public \
       | tee /etc/apt/keyrings/adoptium.asc >/dev/null \
    && chmod a+r /etc/apt/keyrings/adoptium.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(. /etc/os-release && echo "${VERSION_CODENAME}") main" \
       > /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends temurin-21-jdk temurin-17-jdk \
    && update-alternatives --set java /usr/lib/jvm/temurin-21-jdk-amd64/bin/java \
    && update-alternatives --set javac /usr/lib/jvm/temurin-21-jdk-amd64/bin/javac \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
       -o /tmp/maven.tgz \
    && tar -xzf /tmp/maven.tgz -C /opt \
    && ln -sfn "/opt/apache-maven-${MAVEN_VERSION}" /opt/maven \
    && ln -sfn /opt/maven/bin/mvn /usr/local/bin/mvn \
    && rm -f /tmp/maven.tgz

# --- standalone CLI tools ---------------------------------------------------
RUN retry 4 bash -c 'curl -fsSL https://starship.rs/install.sh -o /tmp/starship.sh && sh /tmp/starship.sh -y --bin-dir /usr/local/bin' \
    && rm -f /tmp/starship.sh

RUN retry 4 bash -c 'curl -fsSL https://mise.run -o /tmp/mise.sh && sh /tmp/mise.sh' \
    && MISE_BIN="$(command -v mise || echo /root/.local/bin/mise)" \
    && install -m 0755 "${MISE_BIN}" /usr/local/bin/mise \
    && rm -rf /root/.local /tmp/mise.sh

RUN retry 4 bash -c 'curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv.sh && sh /tmp/uv.sh' \
    && UV_BIN="$(command -v uv || echo /root/.local/bin/uv)" \
    && install -m 0755 "${UV_BIN}" /usr/local/bin/uv \
    && ln -sf /usr/local/bin/uv /usr/local/bin/uvx \
    && rm -rf /root/.local /tmp/uv.sh

# --- Docker CLI only (the daemon stays on the host) -------------------------
RUN install -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
       | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin docker-buildx-plugin \
    && rm -rf /var/lib/apt/lists/*

# --- Google Cloud -----------------------------------------------------------
RUN install -d /usr/share/keyrings \
    && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
       | gpg --dearmor --yes -o /usr/share/keyrings/cloud.google.gpg \
    && chmod a+r /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
       > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin kubectl \
    && rm -rf /var/lib/apt/lists/*

# --- Azure ------------------------------------------------------------------
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
    && rm -rf /var/lib/apt/lists/*

# The azd tarball stores the binary as `azd-linux-<arch>`, not `azd`.
RUN ARCH="$(dpkg --print-architecture)" \
    && retry 4 curl -fsSL \
         "https://github.com/Azure/azure-dev/releases/latest/download/azd-linux-${ARCH}.tar.gz" \
         -o /tmp/azd.tgz \
    && mkdir -p /tmp/azd \
    && tar -xzf /tmp/azd.tgz -C /tmp/azd \
    && install -m 0755 "/tmp/azd/azd-linux-${ARCH}" /usr/local/bin/azd \
    && rm -rf /tmp/azd /tmp/azd.tgz

# --- per-user toolchains ----------------------------------------------------
COPY versions/mise.toml /tmp/mise.toml

RUN install -d -o "${USER_NAME}" -g "${USER_NAME}" \
      "/home/${USER_NAME}/.config" \
      "/home/${USER_NAME}/.config/mise" \
    && install -m 0644 -o "${USER_NAME}" -g "${USER_NAME}" /tmp/mise.toml "/home/${USER_NAME}/.config/mise/config.toml" \
    && retry 6 sudo -u "${USER_NAME}" -H mise install \
    && retry 3 sudo -u "${USER_NAME}" -H mise exec -- npm install -g \
         pnpm azure-functions-core-tools@4 @azure/static-web-apps-cli azurite

# uv downloads its Python builds from GitHub releases too.
RUN retry 6 sudo -u "${USER_NAME}" -H uv python install 3.12

RUN retry 4 sudo -u "${USER_NAME}" -H bash -c \
    'curl --proto =https --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal'

# Install opencode from npm: the platform binary ships in an npm package, so
# this does not depend on GitHub's release CDN the way the curl installer does.
# npm puts the binary in the mise-managed Node prefix; link it somewhere
# non-interactive shells (docker exec) can find it.
RUN retry 3 sudo -u "${USER_NAME}" -H bash -c \
      'cd /tmp && mise exec -- npm install -g opencode-ai' \
    && OC_BIN="$(sudo -u "${USER_NAME}" -H mise exec -- npm prefix -g | tail -n1)/bin/opencode" \
    && test -x "${OC_BIN}" \
    && ln -sf "${OC_BIN}" /usr/local/bin/opencode \
    && sudo -u "${USER_NAME}" -H opencode --version

# --- dotfiles ---------------------------------------------------------------
# Applied with a small script instead of chezmoi, so the image build does not
# depend on another GitHub release download.
COPY dotfiles /opt/dotfiles
COPY container/apply-dotfiles.sh /usr/local/bin/apply-dotfiles

RUN chmod 0755 /usr/local/bin/apply-dotfiles \
    && chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}/.config" \
    && sudo -u "${USER_NAME}" -H /usr/local/bin/apply-dotfiles /opt/dotfiles

# --- sshd (optional, enabled at runtime) ------------------------------------
RUN mkdir -p /run/sshd \
    && ssh-keygen -A \
    && printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin no\n' \
       > /etc/ssh/sshd_config.d/99-dev-env.conf

# --- entrypoint and verifier ------------------------------------------------
COPY container/entrypoint.sh /usr/local/bin/dev-entrypoint
COPY container/verify.sh /usr/local/bin/dev-verify
RUN chmod 0755 /usr/local/bin/dev-entrypoint /usr/local/bin/dev-verify

ENV USER_NAME=${USER_NAME}
ENV PATH="/home/${USER_NAME}/.local/bin:/home/${USER_NAME}/.cargo/bin:/home/${USER_NAME}/.opencode/bin:/home/${USER_NAME}/.local/share/mise/shims:${PATH}"

RUN mkdir -p /workspace && chown "${USER_NAME}:${USER_NAME}" /workspace

USER ${USER_NAME}
WORKDIR /workspace
EXPOSE 2222
ENTRYPOINT ["/usr/local/bin/dev-entrypoint"]
CMD ["sleep", "infinity"]
