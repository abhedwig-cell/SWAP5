#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="128e5c179686377e577c4626df936e3695d57b51"
RIBASIM_PIN="f965a3266a4685bf10f3458aaa1855d09fa45a7a"
RIBASIM_ROOT="${RIBASIM_ROOT:-$ROOT/.ribasim-pin}"

fail(){ echo "RIBASIM_DUMMY_19I2_FAIL $*" >&2; exit 73; }

git merge-base --is-ancestor "$BASE" HEAD || fail "branch is not descended from DUMMY-19I2 preregistration base"
git diff --quiet "$BASE"..HEAD -- src || fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference || fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_19I2_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_19I2_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_19I2_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_19I2_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/real_ribasim_bmi_shadow_applied_bridge.jl) ;;
    tests/research/run_ribasim_dummy_19i2.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-19I2 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_19I2_SOURCE_SCOPE=PASS"
test -d "$RIBASIM_ROOT/.git" || fail "pinned Ribasim checkout missing"
ACTUAL_PIN="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL_PIN" = "$RIBASIM_PIN" || fail "Ribasim checkout mismatch"
echo "RIBASIM_DUMMY_19I2_RIBASIM_PIN=PASS sha=$ACTUAL_PIN"

(
  cd "$RIBASIM_ROOT"
  pixi run python "$ROOT/tests/research/generate_real_ribasim_bmi_management_clock.py" "$RIBASIM_ROOT/generated_testmodels"
  pixi run instantiate-julia
  JULIA_NUM_THREADS=2 pixi run julia --startup-file=no --project=. "$ROOT/tests/research/real_ribasim_bmi_shadow_applied_bridge.jl" "$RIBASIM_ROOT"
)

echo "RIBASIM_DUMMY_19I2_REAL_RIBASIM_TESTS=PASS"
echo "RIBASIM_DUMMY_19I2_GATE=PASS"
