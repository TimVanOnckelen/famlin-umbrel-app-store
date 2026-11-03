#!/usr/bin/env bash
# Point the app at a new Famlin version: image tag + digest, version, releaseNotes.
# Usage: bump.sh X.Y.Z sha256:<index digest>   (env: BREAKING=true, ROOT=repo root)
set -euo pipefail

version="${1:?usage: bump.sh X.Y.Z sha256:DIGEST}"
digest="${2:?usage: bump.sh X.Y.Z sha256:DIGEST}"
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "'$version' is not an X.Y.Z version" >&2
  exit 1
fi
if ! [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "'$digest' is not a sha256 digest" >&2
  exit 1
fi
root="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$root"

compose=famlin-famlin/docker-compose.yml
manifest=famlin-famlin/umbrel-app.yml

sed -i -E "s|image: ghcr.io/timvanonckelen/famlin:.*|image: ghcr.io/timvanonckelen/famlin:${version}@${digest}|" "$compose"
sed -i -E "s|^version: .*|version: \"${version}\"|" "$manifest"
VERSION="$version" python3 - "$manifest" <<'PY'
import os, re, sys
p = sys.argv[1]
s = open(p).read()
note = "releaseNotes: >-\n  See https://github.com/TimVanOnckelen/famlin/releases/tag/v%s for what changed." % os.environ["VERSION"]
if os.environ.get("BREAKING") == "true":
    note += " This release contains breaking changes, read the release notes before updating."
s, n = re.subn(r"releaseNotes: >-\n(?:  .*\n)+", note + "\n", s)
assert n == 1, "releaseNotes block not found"
open(p, "w").write(s)
PY

grep -qxF "    image: ghcr.io/timvanonckelen/famlin:${version}@${digest}" "$compose"
grep -qx "version: \"${version}\"" "$manifest"
