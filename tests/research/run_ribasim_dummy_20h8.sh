#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="7fa8550ab4ffd5332370391f01bf4850117c9e2a"
RIBASIM_RELEASE="e7fc8ade52a4bedeec10e508d2065577f33eb76a"
RIBASIM_ROOT="${RIBASIM_DUMMY_20H8_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"

fail() { echo "RIBASIM_DUMMY_20H8_FAIL $*" >&2; exit 73; }

git merge-base --is-ancestor "$BASE" HEAD || fail "branch is not descended from post-H7 authority"
git diff --quiet "$BASE"..HEAD -- src || fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference || fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_20H8_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_20H8_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_20H8_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_20H8_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/real_ribasim_20h8_forcing_sign_asymmetry.jl) ;;
    tests/research/run_ribasim_dummy_20h8.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-20H8 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_20H8_SOURCE_SCOPE=PASS"
test -d "$RIBASIM_ROOT/.git" || fail "exact Ribasim release checkout missing"
ACTUAL="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL" = "$RIBASIM_RELEASE" || fail "Ribasim release mismatch: $ACTUAL"
echo "RIBASIM_DUMMY_20H8_RIBASIM_RELEASE=PASS sha=$ACTUAL"

(
  cd "$RIBASIM_ROOT"
  pixi run python     "$ROOT/tests/research/generate_ribasim_dummy_20h6_next_boundary.py"     "$RIBASIM_ROOT/generated_testmodels/swap5_dummy_20h8"
  pixi run instantiate-julia
  JULIA_NUM_THREADS=2 pixi run julia     --startup-file=no     --project=.     "$ROOT/tests/research/real_ribasim_20h8_forcing_sign_asymmetry.jl"     "$RIBASIM_ROOT/generated_testmodels/swap5_dummy_20h8/ribasim.toml"
)

echo "RIBASIM_DUMMY_20H8_EXACT_RELEASE_SIGN_TESTS=PASS"
echo "RIBASIM_DUMMY_20H8_GATE=PASS"
