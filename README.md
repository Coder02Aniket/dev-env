# Portable Dev Environment

A container-first development environment that turns any fresh Linux VM into the
same machine, whether the host runs Ubuntu, Debian, Rocky, Alma, RHEL, CentOS, or
Fedora.

The host installs **Docker only**. Every tool, runtime, CLI, and dotfile lives in
one image built on Ubuntu 24.04, so the guest userspace is identical everywhere.

## Architecture

```
VM host  (any supported distro)
│
├── Docker Engine            ← the only distro-specific install
│
├── dev container            ← Ubuntu 24.04, all toolchains, your shell
│   └── docker CLI ──► host socket
│
└── service containers       ← postgres, mysql, mongo, minio, redis (opt-in)
```

## Quick start

### 1. Cloud VM with cloud-init

`cloud-init/user-data.yaml` is distro-agnostic. Create the VM with it as
user-data. GCP example:

```bash
# Ubuntu host
gcloud compute instances create dev-vm \
  --zone=asia-south1-a \
  --machine-type=e2-standard-2 \
  --image-family=ubuntu-2404-lts-amd64 \
  --image-project=ubuntu-os-cloud \
  --project=<your gcp project name> \
  --metadata-from-file=user-data=cloud-init/user-data.yaml

# Rocky 9 host, same user-data
gcloud compute instances create dev-vm \
  --zone=asia-south1-a \
  --machine-type=e2-standard-2 \
  --image-family=rocky-linux-9 \
  --project=<your gcp project name> \
  --image-project=rocky-linux-cloud \
  --metadata-from-file=user-data=cloud-init/user-data.yaml
```

AWS EC2 ("User data") and Azure ("Custom data") take the same file.

After a few minutes:

```bash
IP=$(gcloud compute instances describe dev-vm \
  --zone=asia-south1-a \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

ssh -i ~/.ssh/google_compute_engine aniket@"$IP"
docker exec -it dev zsh
```

### 2. Manual, on a VM you already have

```bash
git clone https://github.com/Coder02Aniket/dev-env.git ~/dev-env
cd ~/dev-env
./bootstrap-host.sh
docker exec -it dev zsh
```

The host script installs Docker if needed, adds you to the `docker` group, and
starts the dev container.

### 3. Existing machine with Docker

```bash
cd ~/dev-env
docker compose -f docker-compose.dev.yaml up -d
docker exec -it dev zsh
```

## Daily use

```bash
make shell          # docker exec -it dev zsh
make verify         # tool versions inside the container
make rebuild        # rebuild image and recreate container
make logs
```

Direct SSH into the container (enabled by default):

```bash
ssh -p 2222 dev@<vm-ip>
```

It uses your host `~/.ssh` (mounted read-only) and copies `authorized_keys`
into the container. Disable it with `SSH_ENABLED=0` in the environment before
`docker compose up`.

VS Code: install the Dev Containers extension, open this repo, and choose
"Reopen in Container". JetBrains Gateway can attach to the same container.

## Services (opt-in, never autostart)

`infra/compose.yaml` defines Postgres with pgvector, MySQL, MongoDB, MinIO, and
Redis. Start only what you need:

```bash
make services-up S=postgres
make services-up S="postgres minio"
make services-ps
make services-down
```

From inside the container the repo is mounted at `/opt/dev-env`:

```bash
make -C /opt/dev-env services-up S=postgres
```

The dev container uses host networking, so `localhost:5432`, `localhost:3306`,
and the rest work exactly as your projects expect.

## What is installed in the container

| Area | Contents |
|---|---|
| Base | git, gh, curl, jq, ripgrep, fd, tmux, htop, tree, httpie, direnv |
| Shell | zsh, starship, tmux config, git identity |
| Java | Temurin JDK 21 (default) and 17, Maven 3.9 |
| Python | uv, pipx, Python 3.12 |
| Node | Node 22, Bun, pnpm |
| Native | gcc, clang, cmake, gdb, valgrind, make |
| Rust / Go | rustup stable, Go latest |
| Containers | Docker CLI, buildx, compose plugin |
| Azure | az, azd, Functions Core Tools 4, SWA CLI, Azurite |
| Google Cloud | gcloud, GKE auth plugin, kubectl |
| Agents | opencode (installed, not signed in) |

## Image and updates

The image is `ghcr.io/coder02aniket/dev-env:latest`, built by GitHub Actions on
every change under `container/`, `dotfiles/`, or `versions/`.

> GHCR packages created by Actions default to **private**. If you want VMs to pull
> it anonymously, open the package settings on GitHub and change visibility to
> public. Otherwise `bootstrap-host.sh` falls back to a local build.

- Pull a new image: `docker compose -f docker-compose.dev.yaml pull dev && docker compose -f docker-compose.dev.yaml up -d`
- Build locally: `make image` then `make rebuild`
- Your `dev-home` volume survives rebuilds, including logins.

> **UID 1000 hosts only.** The published image contains a `dev` account with UID
> 1000. If your host account is not 1000 (for example GCP Rocky, where `rocky`
> already owns 1000 and your user gets 1001), `bootstrap-host.sh` builds a local
> image for your UID instead — and you must **not** `pull` on that machine.
> Pulling would replace the matching image with the 1000 one, and the container
> would lose write access to `/workspace`. Use `make rebuild` there.

Because `dev-home` persists, toolchains installed into it (mise, Rust, uv, opencode)
keep their old versions after an image update. To pick up the new image's
toolchains, run `make reset-home` (this deletes logins) and then `make up`.

If the published image is unavailable, `bootstrap-host.sh` falls back to a local
build automatically.

## Secrets

Nothing secret is in the repo or in user-data.

- SSH public key is injected by cloud-init; the private key stays on your laptop.
- `gh`, `az`, `gcloud`, and `opencode` logins live in `/home/dev`, persisted by
  the `dev-home` volume.
- Project secrets use `.env` + `.env.example` + direnv.
- Service passwords live in `infra/.env` on the host (gitignored).

Details in `secrets/README.md`.

## Rocky Linux notes

- On EL hosts (`rocky`, `almalinux`, `rhel`, `centos`) the script installs Docker
  CE from Docker's RPM repository itself instead of using `get.docker.com`.
  Rocky resolves `$releasever` to a minor version (`9.6`), but Docker only
  publishes major-version paths (`/centos/9`), so the script pins
  `$releasever` to the major version before installing.
- If that still fails, the equivalent manual commands are:

  ```bash
  sudo dnf install -y dnf-plugins-core
  sudo curl -fsSL https://download.docker.com/linux/centos/docker-ce.repo \
    -o /etc/yum.repos.d/docker-ce.repo
  sudo sed -i "s|\$releasever|$(rpm -E %rhel)|g" /etc/yum.repos.d/docker-ce.repo
  sudo dnf install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER"
  ```

  Docker publishes `centos/8`, `centos/9`, and `centos/10`. EL7 is unsupported.
- Fedora uses its own Docker path, so it still goes through `get.docker.com`.
- SELinux is handled: the repo and workspace mounts carry the `:z` label.
- firewalld only matters if you expose service ports outside the VM.

## Legacy native path

The original apt-only installer is in `native/` and still works on Ubuntu/Debian:

```bash
make native-bootstrap
```

It is no longer the default and does not support Rocky.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `permission denied` on docker | log out and back in, or `newgrp docker` |
| container not starting | `docker compose -f docker-compose.dev.yaml logs dev` |
| image pull fails | `make rebuild` builds locally |
| SSH to container refused | check `SSH_ENABLED=1` and host `~/.ssh/authorized_keys` |
| service port already in use | `make services-down` or change `infra/.env` |
| workspace files owned by root | run `bootstrap-host.sh` as your user, not root |

## Layout

```
container/              Dockerfile, entrypoint, in-container verify
.devcontainer/          VS Code / JetBrains attach config
docker-compose.dev.yaml dev container definition
bootstrap-host.sh       host layer: Docker + start container
cloud-init/             first-boot trigger (distro-agnostic)
dotfiles/               shell/tmux/git config, baked into the image
infra/                  service containers
versions/mise.toml      Node, Bun, Go pins
native/                 legacy apt-only installer
secrets/                rules and future age bundle
```

## Validation

```bash
docker exec dev dev-verify
# or, from inside the container
dev-verify
```

Expect `PASS: all core tools present` and `containers running: 0` until you start
services.
