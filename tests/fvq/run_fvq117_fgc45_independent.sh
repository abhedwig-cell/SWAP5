#!/usr/bin/env bash
set -euo pipefail
BASE="$(git merge-base HEAD origin/integration/f-ci-canonical)"
if git diff --name-only "$BASE" HEAD -- src/ | grep -q .; then
  echo 'FVQ117_FAIL production source delta is not zero' >&2
  git diff --name-only "$BASE" HEAD -- src/ >&2
  exit 1
fi
python3 tests/fvq/test_fvq117_fgc45_independent.py
echo 'FVQ117_PRODUCTION_DELTA_NONE=PASS'
echo 'F-VQ117 F-GC45 INDEPENDENT QUALIFICATION PASS'
