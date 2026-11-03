#!/usr/bin/env bash
# The checks lint.yml and update.yml share: yamllint + compose validation.
# Needs yamllint and docker on PATH.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

yamllint -c .yamllint.yml .

export APP_DATA_DIR="${APP_DATA_DIR:-/tmp/famlin-data}"
export APP_SEED="${APP_SEED:-0000000000000000000000000000000000000000000000000000000000000000}"
export APP_HOST="${APP_HOST:-famlin.local}"
stub="$(mktemp)"
trap 'rm -f "$stub"' EXIT
# Umbrel injects the app_proxy image at install time; stub it so compose can
# validate the file on its own.
printf 'services:\n  app_proxy:\n    image: busybox\n' >"$stub"
docker compose -f famlin-famlin/docker-compose.yml -f "$stub" config --quiet
