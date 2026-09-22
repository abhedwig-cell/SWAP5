#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="e5b2a00556655a632411b262dc9653af65a2c1a0"
RIBASIM_RELEASE="e7fc8ade52a4bedeec10e508d2065577f33eb76a"
RIBASIM_ROOT="${RIBASIM_DUMMY_20H6_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"

fail() { echo "RIBASIM_DUMMY_20H6_FAIL $*" >&2; exit 73; }

git merge-base --is-ancestor "$BASE" HEAD || fail "branch is not descended from post-20H5 authority"
git diff --quiet "$BASE"..HEAD -- src || fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference || fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_20H6_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_20H6_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_20H6_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_20H6_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/generate_ribasim_dummy_20h6_next_boundary.py) ;;
    tests/research/real_ribasim_20h6_next_boundary_memory.jl) ;;
    tests/research/run_ribasim_dummy_20h6.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-20H6 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_20H6_SOURCE_SCOPE=PASS"
test -d "$RIBASIM_ROOT/.git" || fail "exact Ribasim release checkout missing"
ACTUAL="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL" = "$RIBASIM_RELEASE" || fail "Ribasim release mismatch: $ACTUAL"
echo "RIBASIM_DUMMY_20H6_RIBASIM_RELEASE=PASS sha=$ACTUAL"

(
  cd "$RIBASIM_ROOT"
  pixi run python     "$ROOT/tests/research/generate_ribasim_dummy_20h6_next_boundary.py"     "$RIBASIM_ROOT/generated_testmodels/swap5_dummy_20h6"
  pixi run instantiate-julia
  JULIA_NUM_THREADS=2 pixi run julia     --startup-file=no     --project=.     "$ROOT/tests/research/real_ribasim_20h6_next_boundary_memory.jl"     "$RIBASIM_ROOT/generated_testmodels/swap5_dummy_20h6/ribasim.toml"
)

echo "RIBASIM_DUMMY_20H6_EXACT_RELEASE_MEMORY_FORECAST_TESTS=PASS"
echo "RIBASIM_DUMMY_20H6_GATE=PASS"
