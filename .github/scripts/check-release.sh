#!/usr/bin/env bash
# Decide whether this repo should move to a newer Famlin release.
#
# Inputs (environment):
#   CURRENT        version this repo currently points at (required)
#   INPUT_VERSION  optional explicit target (workflow_dispatch / repository_dispatch);
#                  default is the latest GitHub release of Famlin
#   GH_TOKEN       optional, only used to raise the GitHub API rate limit
#
# Writes to $GITHUB_OUTPUT: status (up-to-date | image-pending | update),
# version, digest, breaking (true | false), release_url.
# Writes a one-line summary to $GITHUB_STEP_SUMMARY.
set -euo pipefail

FAMLIN_REPO="${FAMLIN_REPO:-TimVanOnckelen/famlin}"
FAMLIN_IMAGE="${FAMLIN_IMAGE:-ghcr.io/timvanonckelen/famlin}"
SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+$'

# True when $1 is strictly newer than $2 (plain X.Y.Z versions).
version_gt() {
  [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" == "$1" ]]
}

# is_breaking TARGET CURRENT BODY: major bump, or the release notes carry the
# "BREAKING CHANGES" section release-please writes for `feat!:` commits.
is_breaking() {
  if [[ "${1%%.*}" -gt "${2%%.*}" ]]; then
    return 0
  fi
  grep -q 'BREAKING CHANGES' <<<"$3"
}

# fetch_release latest | tags/vX.Y.Z -> release JSON on stdout
fetch_release() {
  local auth=()
  if [[ -n "${GH_TOKEN:-}" ]]; then
    auth=(-H "Authorization: Bearer ${GH_TOKEN}")
  fi
  curl -fsSL --retry 3 \
    -H 'Accept: application/vnd.github+json' \
    "${auth[@]}" \
    "https://api.github.com/repos/${FAMLIN_REPO}/releases/$1"
}

# image_digest X.Y.Z -> index digest (sha256:...) or nothing if not published
image_digest() {
  docker buildx imagetools inspect "${FAMLIN_IMAGE}:$1" --format '{{json .Manifest}}' 2>/dev/null \
    | jq -r '.digest // empty' || true
}

emit() { echo "$1=$2" >>"${GITHUB_OUTPUT:-/dev/stdout}"; }
# finish STATUS [DIGEST] [BREAKING]
finish() {
  emit status "$1"
  emit digest "${2:-}"
  emit breaking "${3:-false}"
}
summary() { echo "$1" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"; }

main() {
  : "${CURRENT:?CURRENT is required}"
  local want="${INPUT_VERSION:-}"
  want="${want#v}"

  local json
  if [[ -n "$want" ]]; then
    if ! [[ "$want" =~ $SEMVER_RE ]]; then
      echo "::error::'$want' is not an X.Y.Z version" >&2
      return 1
    fi
    json=$(fetch_release "tags/v${want}") || {
      echo "::error::No Famlin release v${want} found" >&2
      return 1
    }
  else
    json=$(fetch_release latest) || {
      echo "::error::Could not read the latest Famlin release" >&2
      return 1
    }
  fi

  local tag version body url
  tag=$(jq -r '.tag_name' <<<"$json")
  version="${tag#v}"
  body=$(jq -r '.body // ""' <<<"$json")
  url=$(jq -r '.html_url' <<<"$json")
  emit version "$version"
  emit release_url "$url"

  if ! [[ "$version" =~ $SEMVER_RE ]]; then
    finish up-to-date
    summary "Latest release tag '${tag}' is not a plain X.Y.Z version: ignored."
    return 0
  fi

  if ! version_gt "$version" "$CURRENT"; then
    finish up-to-date
    summary "Already up to date (current ${CURRENT}, latest Famlin release ${version})."
    return 0
  fi

  local digest
  digest=$(image_digest "$version")
  if [[ "$digest" != sha256:* ]]; then
    finish image-pending
    summary "Famlin ${version} is released but image ${FAMLIN_IMAGE}:${version} is not published yet. Will retry on the next run."
    return 0
  fi

  if is_breaking "$version" "$CURRENT" "$body"; then
    finish update "$digest" true
  else
    finish update "$digest" false
  fi
  summary "Update available: ${CURRENT} -> ${version} (${digest})."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
