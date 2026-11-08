# Secrets

The bootstrap ships with **Tier 0**: no secret manager, no secrets in the repo,
no secrets in user-data.

## What lives where

| Secret | Location | How it gets there |
|---|---|---|
| SSH key pair | your laptop; public key in user-data | cloud-init injects the public key |
| GitHub auth | `~/.config/gh/hosts.yml` | `gh auth login` once per VM |
| Azure auth | `~/.azure/` | `az login --use-device-code` once per VM |
| GCP auth | `~/.config/gcloud/` | `gcloud auth login` once per VM |
| opencode auth | `~/.local/share/opencode/` | `opencode auth login` once per VM |
| Project secrets | `project/.env` (gitignored) | copied or re-entered by you |
| Service passwords | `infra/.env` (gitignored) | generated from `.env.example` |

`direnv` loads a project's `.env` automatically when you `cd` into it. Keep a
committed `.env.example` with placeholder values.

## Rules

1. Never commit `.env`, tokens, or private keys.
2. Never put secrets in `cloud-init/user-data.yaml`. The metadata endpoint
   (`169.254.169.254`) exposes it to anything running in the VM, and some
   providers log it.
3. Treat VM images and snapshots as public. Anything baked in can leak.
4. If a token leaks, rotate it. Do not try to scrub the image.

## Future: age bundle (Tier 1)

When per-VM logins become annoying, add an age-encrypted bundle:

1. Generate a key once on your laptop: `age-keygen -o key.txt`
2. Encrypt a bundle: `age -e -r <public-key> -o secrets.age secrets.plain`
3. Bootstrap will decrypt it: `./bootstrap.sh --with-secrets /path/to/key.txt`

The flag is reserved and currently ignored. The intended flow is to decrypt into
`~/.config/dev-env/secrets.env` with mode `0600` and never write it to the repo.
