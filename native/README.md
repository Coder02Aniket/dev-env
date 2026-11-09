# Legacy native installer

This folder is the original apt-only installer for Ubuntu/Debian. It is kept as
a fallback and is no longer the default path.

The supported path is the container-first setup in the repository root:

```bash
./bootstrap-host.sh      # host: install Docker, start the dev container
docker exec -it dev zsh  # container: everything else
```

The native path still works on Ubuntu 22.04/24.04 and Debian 12:

```bash
./native/bootstrap.sh
bash native/lib/verify.sh
```

It shares `dotfiles/`, `infra/`, and `versions/` with the container build, so
changes there affect both. It does not support Rocky Linux.
