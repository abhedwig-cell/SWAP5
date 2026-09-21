#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="eff2f9334bc86e649747df2f60872f83f8d08214"
RIBASIM_PIN="f965a3266a4685bf10f3458aaa1855d09fa45a7a"
RIBASIM_ROOT="${RIBASIM_ROOT:-$ROOT/.ribasim-pin}"

fail() {
  echo "RIBASIM_DUMMY_19A_FAIL $*" >&2
  exit 73
}

git merge-base --is-ancestor "$BASE" HEAD ||
  fail "branch is not descended from qualified DUMMY-18 closeout base"

git diff --quiet "$BASE"..HEAD -- src ||
  fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference ||
  fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_19A_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_19A_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_19A_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_19A_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/real_ribasim_allocation_supply_bridge.jl) ;;
    tests/research/run_ribasim_dummy_19a.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-19A branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_19A_SOURCE_SCOPE=PASS"

test -d "$RIBASIM_ROOT/.git" ||
  fail "pinned Ribasim checkout is missing at $RIBASIM_ROOT"

ACTUAL_PIN="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL_PIN" = "$RIBASIM_PIN" ||
  fail "Ribasim checkout mismatch: expected $RIBASIM_PIN, got $ACTUAL_PIN"

echo "RIBASIM_DUMMY_19A_RIBASIM_PIN=PASS sha=$ACTUAL_PIN"
pixi --version

(
  cd "$RIBASIM_ROOT"

  # Use the pinned repository's own Python model constructors and Pixi environment.
  pixi run python utils/generate-testmodels.py     level_demand     fair_distribution     two_basin_user_demand

  # Use the pinned repository's own Julia project and manifest.
  pixi run instantiate-julia
  pixi run julia --startup-file=no --project=. --version

  JULIA_NUM_THREADS=2 pixi run julia     --startup-file=no     --project=.     "$ROOT/tests/research/real_ribasim_allocation_supply_bridge.jl"     "$RIBASIM_ROOT"
)

echo "RIBASIM_DUMMY_19A_REAL_RIBASIM_TESTS=PASS"
echo "RIBASIM_DUMMY_19A_GATE=PASS"
