#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="4b1c81287cecc65ca94da101905366540b756284"
RIBASIM_PIN="f965a3266a4685bf10f3458aaa1855d09fa45a7a"
RIBASIM_ROOT="${RIBASIM_ROOT:-$ROOT/.ribasim-pin}"

fail() {
  echo "RIBASIM_DUMMY_19G_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from qualified DUMMY-19E2 closeout base"

git diff --quiet "$BASE"..HEAD -- src || fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference || fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_19G_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_19G_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_19G_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_19G_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/generate_real_ribasim_saveat_sensitivity.py) ;;
    tests/research/real_ribasim_saveat_sensitivity_bridge.jl) ;;
    tests/research/run_ribasim_dummy_19g.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-19G branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_19G_SOURCE_SCOPE=PASS"

test -d "$RIBASIM_ROOT/.git" || fail "pinned Ribasim checkout missing"
ACTUAL_PIN="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL_PIN" = "$RIBASIM_PIN" || fail "Ribasim checkout mismatch"

echo "RIBASIM_DUMMY_19G_RIBASIM_PIN=PASS sha=$ACTUAL_PIN"

(
  cd "$RIBASIM_ROOT"
  pixi run python     "$ROOT/tests/research/generate_real_ribasim_saveat_sensitivity.py"     "$RIBASIM_ROOT/generated_testmodels"
  pixi run instantiate-julia
  pixi run julia --startup-file=no --project=. --version
  JULIA_NUM_THREADS=2 pixi run julia     --startup-file=no     --project=.     "$ROOT/tests/research/real_ribasim_saveat_sensitivity_bridge.jl"     "$RIBASIM_ROOT"
)

echo "RIBASIM_DUMMY_19G_REAL_RIBASIM_TESTS=PASS"
echo "RIBASIM_DUMMY_19G_GATE=PASS"
