#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="b3337bffc3595e03358b50293ba30e003547fd88"
RIBASIM_RELEASE_SHA="e7fc8ade52a4bedeec10e508d2065577f33eb76a"
RIBASIM_ROOT="${RIBASIM_DUMMY_20B_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"

fail() {
  echo "RIBASIM_DUMMY_20B_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from DUMMY-20B preregistration baseline"

git diff --quiet "$BASE"..HEAD -- src || fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference || fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_20B_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_20B_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_20B_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_20B_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/test_ribasim_dummy_20b_product_release_clock.py) ;;
    tests/research/run_ribasim_dummy_20b.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-20B branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_20B_SOURCE_SCOPE=PASS"

test -d "$RIBASIM_ROOT/.git" || fail "pinned Ribasim release checkout missing"
ACTUAL_SHA="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL_SHA" = "$RIBASIM_RELEASE_SHA" || fail "Ribasim release checkout mismatch"

echo "RIBASIM_DUMMY_20B_RIBASIM_RELEASE_PIN=PASS sha=$ACTUAL_SHA"

RIBASIM_DUMMY_20B_RIBASIM_ROOT="$RIBASIM_ROOT" RIBASIM_DUMMY_20B_RIBASIM_SHA="$ACTUAL_SHA" python tests/research/test_ribasim_dummy_20b_product_release_clock.py

echo "RIBASIM_DUMMY_20B_GATE=PASS"
