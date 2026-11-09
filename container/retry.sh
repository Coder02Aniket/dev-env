#!/usr/bin/env bash
# Retry a command a few times. Builds depend on GitHub release downloads that
# occasionally answer with 5xx; a failed attempt should not fail the image.
#
# usage: retry <attempts> <command...>

set -uo pipefail

attempts="${1:?attempts required}"
shift

for ((i = 1; i <= attempts; i++)); do
  if "$@"; then
    exit 0
  fi
  # Back off progressively: 5s, 10s, 15s, ... A brief 5xx from GitHub's
  # release CDN usually clears within a minute.
  delay=$(( i * 5 ))
  echo "attempt ${i}/${attempts} failed: $* (retrying in ${delay}s)" >&2
  sleep "$delay"
done

echo "giving up after ${attempts} attempts: $*" >&2
exit 1
