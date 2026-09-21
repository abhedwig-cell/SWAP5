#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="62b74ca453b0a365f1f16512843b61be15375287"
RIBASIM_PIN="f965a3266a4685bf10f3458aaa1855d09fa45a7a"
RIBASIM_ROOT="${RIBASIM_ROOT:-$ROOT/.ribasim-pin}"

fail() {
  echo "RIBASIM_DUMMY_19E_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from qualified DUMMY-19D closeout base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_19E_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_19E_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_19E_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_19E_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/generate_real_ribasim_mixed_allocation_realization.py) ;;
    tests/research/real_ribasim_mixed_allocation_realization_bridge.jl) ;;
    tests/research/run_ribasim_dummy_19e.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-19E branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_19E_SOURCE_SCOPE=PASS"

test -d "$RIBASIM_ROOT/.git" ||
  fail "pinned Ribasim checkout is missing at $RIBASIM_ROOT"

ACTUAL_PIN="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL_PIN" = "$RIBASIM_PIN" ||
  fail "Ribasim checkout mismatch: expected $RIBASIM_PIN, got $ACTUAL_PIN"

echo "RIBASIM_DUMMY_19E_RIBASIM_PIN=PASS sha=$ACTUAL_PIN"
pixi --version

(
  cd "$RIBASIM_ROOT"

  pixi run python     "$ROOT/tests/research/generate_real_ribasim_mixed_allocation_realization.py"     "$RIBASIM_ROOT/generated_testmodels"

  pixi run instantiate-julia
  pixi run julia --startup-file=no --project=. --version

  JULIA_NUM_THREADS=2 pixi run julia     --startup-file=no     --project=.     "$ROOT/tests/research/real_ribasim_mixed_allocation_realization_bridge.jl"     "$RIBASIM_ROOT"
)

echo "RIBASIM_DUMMY_19E_REAL_RIBASIM_TESTS=PASS"
echo "RIBASIM_DUMMY_19E_GATE=PASS"
