#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="e045b5245fce9d7d85f65737dd8f6cc4695e1376"
IMOD_PIN="8907fb13f8301ba1e0f32dd90a64ea475d4896d6"
IMOD_ROOT="${RIBASIM_DUMMY_20A_IMOD_COUPLER_ROOT:-$ROOT/.imod-coupler-pin}"

fail() {
  echo "RIBASIM_DUMMY_20A_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from DUMMY-20A preregistration baseline"

git diff --quiet "$BASE"..HEAD -- src || fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference || fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_20A_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_20A_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_20A_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_20A_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/test_ribasim_dummy_20a_ribamod_product_clock.py) ;;
    tests/research/run_ribasim_dummy_20a.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-20A branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_20A_SOURCE_SCOPE=PASS"

test -d "$IMOD_ROOT/.git" || fail "pinned iMOD Coupler checkout missing"
ACTUAL_PIN="$(git -C "$IMOD_ROOT" rev-parse HEAD)"
test "$ACTUAL_PIN" = "$IMOD_PIN" || fail "iMOD Coupler checkout mismatch"

echo "RIBASIM_DUMMY_20A_IMOD_COUPLER_PIN=PASS sha=$ACTUAL_PIN"

RIBASIM_DUMMY_20A_IMOD_COUPLER_ROOT="$IMOD_ROOT" RIBASIM_DUMMY_20A_IMOD_COUPLER_SHA="$ACTUAL_PIN" python tests/research/test_ribasim_dummy_20a_ribamod_product_clock.py

echo "RIBASIM_DUMMY_20A_GATE=PASS"
