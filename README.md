# Portable Dev Environment

One repository that turns a fresh Ubuntu/Debian VM into a fully configured
development machine on first boot, and keeps it consistent across every VM you
create.

The design is deliberately two-layered:

1. `cloud-init/user-data.yaml` is a thin trigger. It clones this repo and runs
   `bootstrap.sh` once, at first boot.
2. `bootstrap.sh` plus the dotfiles do all the real work. They are idempotent,
   so the same script works on cloud VMs, local hypervisors, and plain SSH
   sessions, and can be re-run after a failure.

Bootstrap never starts your application services. They are defined and ready,
and you start them when you need them.

## Two ways to run this

You only need one. They both end in the same place: `bootstrap.sh` running on the
VM as a normal user.

### Option A: manual, on any VM you can already log into

This is the "SSH in and run something" path. It works on cloud VMs, Proxmox,
Hyper-V, VirtualBox, or a machine you already own.

```bash
# on the VM, as your normal user (not root)
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/Coder02Aniket/dev-env.git ~/dev-env
cd ~/dev-env
./bootstrap.sh
```

Nothing else is required. The repo is public, so the clone needs no credentials.

### Option B: automatic at first boot (cloud-init)

Paste `cloud-init/user-data.yaml` into the VM's user-data field at creation. The
VM clones the repo and runs `bootstrap.sh` itself before you log in. This is just
Option A automated, plus it creates your `aniket` user and installs your SSH
public key so you can connect afterwards.

The public key in that file is yours. The private half stays on your laptop at
`~/.ssh/google_compute_engine`, and you connect with:

```bash
ssh -i ~/.ssh/google_compute_engine aniket@<VM_IP>
```

## Quick start

### Cloud VM (Ubuntu 24.04)

The repo and your SSH public key are already wired into `cloud-init/user-data.yaml`.
Create the VM with that file as user-data. Example with the gcloud CLI:

```bash
gcloud compute instances create dev-vm \
  --zone=asia-south1-a \
  --machine-type=e2-standard-2 \
  --image-family=ubuntu-2404-lts-amd64 \
  --image-project=ubuntu-os-cloud \
  --metadata-from-file=user-data=cloud-init/user-data.yaml
```

Then wait a few minutes and connect:

```bash
IP=$(gcloud compute instances describe dev-vm \
  --zone=asia-south1-a \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
ssh -i ~/.ssh/google_compute_engine aniket@"$IP"
```

AWS EC2 and Azure VMs work the same way: paste the file into the "User data" or
"Custom data" field at creation, then SSH in as `aniket`.

Progress is logged to `/var/log/cloud-init-output.log`.

> The repo contains no secrets, so it is safe to make it public. If you keep it
> private, add a read-only deploy key or a fine-grained token to the clone step,
> and remember that user-data is readable from inside the VM.

### Local VM (Proxmox, Hyper-V gen2, VirtualBox)

Build a NoCloud seed ISO and attach it as a second CD-ROM, then boot the
Ubuntu 24.04 cloud image:

```bash
cloud-localds seed.iso cloud-init/user-data.yaml cloud-init/meta-data.yaml
```

Hyper-V and VirtualBox need the same seed ISO; Proxmox has a native
"Cloud-init" drive where you can paste `user-data.yaml` directly.

### Existing VM or plain SSH

```bash
git clone https://github.com/<you>/dev-env.git ~/dev-env
cd ~/dev-env
./bootstrap.sh
```

## What gets installed

| Area | Contents |
|---|---|
| Base | build-essential, git, gh, curl, jq, ripgrep, fd, tmux, htop, tree, httpie, direnv |
| Shell | zsh + starship, sensible history and aliases |
| Java | Temurin JDK 21 (default) and JDK 17, Maven 3.9 |
| Python | uv, pipx, Python 3.12 |
| Node | Node 22 LTS via mise, Bun, pnpm |
| Native | gcc, clang, cmake, gdb, valgrind, make |
| Rust / Go | rustup stable, Go latest stable via mise |
| Containers | Docker Engine, buildx, compose plugin, non-root `docker` group |
| Azure | az, azd, Azure Functions Core Tools 4, SWA CLI, Azurite |
| Google Cloud | gcloud CLI, GKE auth plugin, kubectl |
| Agents | opencode (installed, not signed in) |

## Local services (opt-in)

`infra/compose.yaml` defines Postgres with pgvector, MySQL, MongoDB, MinIO, and
Redis. Nothing starts automatically.

```bash
make up                  # start everything
make up S=postgres       # start one service
make up S="postgres minio"
make ps                  # health and ports
make logs S=minio
make down                # stop, keep volumes
make pull                # pre-pull images without starting
```

Ports are standard (5432, 3306, 27017, 9000/9001, 6379) and configurable through
`infra/.env`. If a project ships its own compose file, either point that project
at this stack or run `make down` first to avoid port conflicts.

Override any value by editing `infra/.env` (created from `.env.example`).

## Secrets

Deliberately simple, with an upgrade path:

- SSH public key is injected by cloud-init. Private keys never touch the VM image.
- Sign in once per VM: `gh auth login`, `az login --use-device-code`,
  `gcloud auth login`, `opencode auth login`.
- Project secrets live in `.env` files, covered by `.gitignore`, with a committed
  `.env.example`. direnv loads them when you `cd` into a project.
- Never put secrets in `cloud-init/user-data.yaml`: it is readable from inside
  the VM via the metadata endpoint.

An optional age-encrypted bundle is planned: `./bootstrap.sh --with-secrets <keyfile>`.
See `secrets/README.md`.

## IDE on a headless VM

`bootstrap.sh` does not install a GUI IDE. Use one of:

- **VS Code Remote-SSH** (free): install `code` on your laptop, connect to the
  VM, install extensions remotely.
- **JetBrains Gateway** (needs IntelliJ IDEA Ultimate): install the backend on
  the VM, connect from Gateway on your laptop.

## Flags

```
./bootstrap.sh                      # full setup
./bootstrap.sh --pull-images        # also pre-pull service images
./bootstrap.sh --skip-services      # do not touch infra/.env or validate compose
./bootstrap.sh --only java          # run one step by name fragment
./bootstrap.sh --with-secrets FILE  # reserved for the age bundle
```

## Idempotency

Every step checks before it acts. Running the script twice is safe and is part
of the acceptance test:

```bash
./bootstrap.sh && ./bootstrap.sh
make verify
```

## Layout

```
bootstrap.sh          entrypoint, runs steps in order
lib/helpers.sh        logging, apt, guards
lib/verify.sh         version and health summary
steps/                one concern per file, numbered
dotfiles/             chezmoi source directory
versions/mise.toml    pinned runtime versions copied to ~/.config/mise
infra/                docker compose stack for local services
cloud-init/           first-boot trigger
secrets/              rules and future age bundle
```

## Troubleshooting

- `docker: permission denied` right after install: log out and back in, or run
  `newgrp docker`. Group membership only applies to new sessions.
- A step failed midway: fix the cause and re-run `./bootstrap.sh`. Completed
  steps are skipped.
- Check what succeeded: `cat .results.tsv`.
- Java version: `sudo update-alternatives --config java` to switch 17 and 21.
