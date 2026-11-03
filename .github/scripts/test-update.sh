#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2329
# Offline tests for check-release.sh and bump.sh. Run from anywhere.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

source "$here/check-release.sh"

fails=0
expect() { # name expected actual
  if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'"; fails=$((fails + 1)); fi
}

# --- version_gt / is_breaking
version_gt 0.9.0 0.8.7 && r=y || r=n; expect "0.9.0 > 0.8.7" y "$r"
version_gt 0.8.7 0.8.7 && r=y || r=n; expect "0.8.7 !> 0.8.7" n "$r"
version_gt 0.8.7 0.8.10 && r=y || r=n; expect "0.8.7 !> 0.8.10" n "$r"
version_gt 0.8.10 0.8.9 && r=y || r=n; expect "0.8.10 > 0.8.9" y "$r"
is_breaking 1.0.0 0.9.0 "" && r=y || r=n; expect "major bump is breaking" y "$r"
is_breaking 0.9.0 0.8.7 "### ⚠ BREAKING CHANGES
* x" && r=y || r=n; expect "body marker is breaking" y "$r"
is_breaking 0.9.0 0.8.7 "### Features" && r=y || r=n; expect "plain minor not breaking" n "$r"

# --- main() with stubbed network
RELEASE_BODY=""
RELEASE_TAG="v0.9.0"
DIGEST="sha256:abc"
fetch_release() { jq -n --arg t "$RELEASE_TAG" --arg b "$RELEASE_BODY" '{tag_name:$t, body:$b, html_url:"https://example/r"}'; }
image_digest() { printf '%s' "$DIGEST"; }
run() { # -> "status breaking version"
  GITHUB_OUTPUT="$tmp/out" GITHUB_STEP_SUMMARY="$tmp/sum"
  export GITHUB_OUTPUT GITHUB_STEP_SUMMARY
  : >"$tmp/out"
  main >/dev/null
  echo "$(sed -n 's/^status=//p' "$tmp/out") $(sed -n 's/^breaking=//p' "$tmp/out") $(sed -n 's/^version=//p' "$tmp/out")"
}
export CURRENT=0.8.7; unset INPUT_VERSION
expect "new minor" "update false 0.9.0" "$(run)"
RELEASE_BODY="### ⚠ BREAKING CHANGES"; expect "marker" "update true 0.9.0" "$(run)"
RELEASE_BODY=""; RELEASE_TAG=v1.0.0; expect "major" "update true 1.0.0" "$(run)"
RELEASE_TAG=v0.8.7; expect "same version" "up-to-date false 0.8.7" "$(run)"
RELEASE_TAG=v0.8.6; expect "never downgrade" "up-to-date false 0.8.6" "$(run)"
RELEASE_TAG=v0.9.0; DIGEST=""; expect "image missing" "image-pending false 0.9.0" "$(run)"
DIGEST="sha256:abc"; RELEASE_TAG=v0.9.0-rc.1; expect "prerelease ignored" "up-to-date false 0.9.0-rc.1" "$(run)"
RELEASE_TAG=v0.9.1; export INPUT_VERSION=v0.9.1; expect "explicit input" "update false 0.9.1" "$(run)"
unset INPUT_VERSION

# --- bump.sh on a scratch copy of the repo files
mkdir -p "$tmp/repo"
cp -r "$repo/famlin-famlin" "$tmp/repo/famlin-famlin"
d=sha256:0000000000000000000000000000000000000000000000000000000000000001
ROOT="$tmp/repo" BREAKING=true bash "$here/bump.sh" 9.9.9 "$d"
expect "image" "    image: ghcr.io/timvanonckelen/famlin:9.9.9@$d" "$(grep 'famlin:9' "$tmp/repo/famlin-famlin/docker-compose.yml")"
expect "postgres untouched" "    image: postgres:16-alpine" "$(grep 'postgres:' "$tmp/repo/famlin-famlin/docker-compose.yml")"
expect "version" 'version: "9.9.9"' "$(grep '^version:' "$tmp/repo/famlin-famlin/umbrel-app.yml")"
expect "release notes" "1" "$(grep -c 'tag/v9.9.9 for what changed. This release contains breaking' "$tmp/repo/famlin-famlin/umbrel-app.yml")"
expect "following key intact" "1" "$(grep -c '^developer: ' "$tmp/repo/famlin-famlin/umbrel-app.yml")"
ROOT="$tmp/repo" bash "$here/bump.sh" 9.9.10 "$d"
expect "second bump, plain notes" "1" "$(grep -c 'tag/v9.9.10 for what changed.$' "$tmp/repo/famlin-famlin/umbrel-app.yml")"

exit "$fails"
