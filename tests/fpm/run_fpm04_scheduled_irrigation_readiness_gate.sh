#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE="55efeb4090a669d179a8d93f73e0799e6c7623c5"

# Fail closed if the readiness unit has touched production source.
if [[ -n "$(git diff --name-only "$BASE" HEAD -- src)" ]]; then
  echo 'FPM04_PRODUCTION_SOURCE_CHANGED_BEFORE_READINESS_PASS' >&2
  git diff --name-only "$BASE" HEAD -- src >&2
  exit 1
fi

# Exact owner/source commits used by the Python gate must be present in the clone.
for commit in \
  fca2f497e465c4782ebc6e25756aff70cbb2554e \
  afb450bed0d53d20af2157d0b164d16a9e0a04cd \
  973d2b9d38917a4a459f51b6b46dd51cfd9690c4; do
  git cat-file -e "${commit}^{commit}"
done

echo 'FPM04_EXACT_COMMIT_PROVENANCE PASS'
python3 tools/fpm/fpm04_scheduled_irrigation_readiness_gate.py
