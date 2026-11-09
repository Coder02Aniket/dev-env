# Secrets

Nothing secret is committed, baked into the image, or placed in
`cloud-init/user-data.yaml`.

## Where things live

| Secret | Location | How it gets there |
|---|---|---|
| SSH key pair | laptop; public key in user-data | cloud-init installs the public key |
| GitHub auth | `/home/dev/.config/gh` inside the container | `gh auth login` once |
| Azure auth | `/home/dev/.azure` inside the container | `az login --use-device-code` once |
| GCP auth | `/home/dev/.config/gcloud` inside the container | `gcloud auth login` once |
| opencode auth | `/home/dev/.local/share/opencode` inside the container | `opencode auth login` once |
| Project secrets | `project/.env` (gitignored) | you create it |
| Service passwords | `infra/.env` on the host (gitignored) | copied from `.env.example` |
| Container sshd access | host `~/.ssh/authorized_keys` (read-only mount) | your existing keys |

The container home is the `dev-home` volume, so all four logins survive image
rebuilds. The workspace is a bind mount, so code survives container deletion.

## Rules

1. Never commit `.env`, tokens, or private keys.
2. Never put secrets in `cloud-init/user-data.yaml`; the metadata endpoint
   (`169.254.169.254`) exposes it to anything running in the VM.
3. Treat VM images and snapshots as public. The dev image contains no secrets by
   design, so a leaked snapshot does not leak credentials.
4. If a token leaks, rotate it. Do not try to scrub images.

## Future: age bundle (Tier 1)

When per-VM logins become annoying, add an age-encrypted bundle:

1. Generate a key once on your laptop: `age-keygen -o key.txt`
2. Encrypt a bundle: `age -e -r <public-key> -o secrets.age secrets.plain`
3. `./bootstrap-host.sh --with-secrets /path/to/key.txt`

The flag is reserved and currently ignored. The intended flow is to decrypt into
`dev-home` at `/home/dev/.config/dev-env/secrets.env` with mode `0600` and never
write it to the repo.
