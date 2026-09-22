#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="3fa962cc200fdcd6d7db197b36d5279df9f0c8e8"
RIBASIM_RELEASE="e7fc8ade52a4bedeec10e508d2065577f33eb76a"
RIBASIM_ROOT="${RIBASIM_DUMMY_20H11_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"

fail() { echo "RIBASIM_DUMMY_20H11_FAIL $*" >&2; exit 73; }

git merge-base --is-ancestor "$BASE" HEAD || fail "branch is not descended from post-H10 authority"
git diff --quiet "$BASE"..HEAD -- src || fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference || fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_20H11_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_20H11_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_20H11_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_20H11_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/generate_ribasim_dummy_20h11_clock_lattice.py) ;;
    tests/research/real_ribasim_20h11_clock_lattice.jl) ;;
    tests/research/run_ribasim_dummy_20h11.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-20H11 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_20H11_SOURCE_SCOPE=PASS"
test -d "$RIBASIM_ROOT/.git" || fail "exact Ribasim release checkout missing"
ACTUAL="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL" = "$RIBASIM_RELEASE" || fail "Ribasim release mismatch: $ACTUAL"
echo "RIBASIM_DUMMY_20H11_RIBASIM_RELEASE=PASS sha=$ACTUAL"

(
  cd "$RIBASIM_ROOT"
  CASE_ROOT="$RIBASIM_ROOT/generated_testmodels/swap5_dummy_20h11"
  pixi run python "$ROOT/tests/research/generate_ribasim_dummy_20h11_clock_lattice.py" "$CASE_ROOT"
  pixi run instantiate-julia
  JULIA_NUM_THREADS=2 pixi run julia     --startup-file=no     --project=.     "$ROOT/tests/research/real_ribasim_20h11_clock_lattice.jl"     "$CASE_ROOT"
)

echo "RIBASIM_DUMMY_20H11_EXACT_RELEASE_CLOCK_LATTICE=PASS"
echo "RIBASIM_DUMMY_20H11_GATE=PASS"
