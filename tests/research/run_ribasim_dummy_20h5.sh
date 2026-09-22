#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASE="0a1051dcf3d333b101d6f0f1f2b92562e3f5cf5a"
RIBASIM_RELEASE="e7fc8ade52a4bedeec10e508d2065577f33eb76a"
RIBASIM_ROOT="${RIBASIM_DUMMY_20H5_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"

fail() { echo "RIBASIM_DUMMY_20H5_FAIL $*" >&2; exit 73; }

git merge-base --is-ancestor "$BASE" HEAD || fail "branch is not descended from DUMMY-20H5 implementation base"
git diff --quiet "$BASE"..HEAD -- src || fail "production src delta is forbidden"
git diff --quiet "$BASE"..HEAD -- reference || fail "reference delta is forbidden"

while IFS= read -r path; do
  case "$path" in
    .github/workflows/ribasim-dummy-01.yml) ;;
    integration/research/RIBASIM_DUMMY_20H5_PREREGISTRATION.json) ;;
    integration/research/RIBASIM_DUMMY_20H5_CONCEPT.md) ;;
    integration/research/RIBASIM_DUMMY_20H5_STATUS.json) ;;
    integration/research/RIBASIM_DUMMY_20H5_RESULT.json) ;;
    integration/research/RIBASIM_DUMMY_PROGRAM_STATUS.json) ;;
    tests/research/generate_ribasim_dummy_20h5_zero_storage.py) ;;
    tests/research/real_ribasim_20h5_zero_storage_causality.jl) ;;
    tests/research/run_ribasim_dummy_20h5.sh) ;;
    "") ;;
    *) fail "unexpected DUMMY-20H5 branch delta: $path" ;;
  esac
done < <(git diff --name-only "$BASE"..HEAD | sort)

echo "RIBASIM_DUMMY_20H5_SOURCE_SCOPE=PASS"
test -d "$RIBASIM_ROOT/.git" || fail "exact Ribasim release checkout missing"
ACTUAL="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL" = "$RIBASIM_RELEASE" || fail "Ribasim release mismatch: $ACTUAL"
echo "RIBASIM_DUMMY_20H5_RIBASIM_RELEASE=PASS sha=$ACTUAL"

(
  cd "$RIBASIM_ROOT"
  pixi run python     "$ROOT/tests/research/generate_ribasim_dummy_20h5_zero_storage.py"     "$RIBASIM_ROOT/generated_testmodels/swap5_dummy_20h5"
  pixi run instantiate-julia
  JULIA_NUM_THREADS=2 pixi run julia     --startup-file=no     --project=.     "$ROOT/tests/research/real_ribasim_20h5_zero_storage_causality.jl"     "$RIBASIM_ROOT/generated_testmodels/swap5_dummy_20h5/ribasim.toml"
)

echo "RIBASIM_DUMMY_20H5_EXACT_RELEASE_CAUSAL_TESTS=PASS"
echo "RIBASIM_DUMMY_20H5_GATE=PASS"
