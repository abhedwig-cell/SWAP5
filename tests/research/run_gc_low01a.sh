#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d -t swap5-low01a-XXXXXX)"
trap 'rm -rf "$BUILD"' EXIT

cd "$ROOT"

fail() {
  echo "LOW01-A FAIL: $*" >&2
  exit 1
}

gfortran -std=f2008 -Wall -Wextra -Werror -O0 -g \
  -J "$BUILD" -I "$BUILD" \
  src/runtime/mod_groundwater_coupling_contract.f90 \
  tests/research/test_gc_low01a_below_profile_equivalence.f90 \
  -o "$BUILD/test_gc_low01a_below_profile_equivalence"

"$BUILD/test_gc_low01a_below_profile_equivalence" | tee "$BUILD/low01a-numeric.txt"
python3 tests/research/test_gc_low01a_source_branch.py | tee "$BUILD/low01a-source.txt"

for marker in \
  'GC_LOW01A_BELOW_PROFILE_LEVELS=PASS' \
  'GC_LOW01A_LEGACY_TYPED_HBOT_EQUIVALENCE=PASS' \
  'GC_LOW01A_HEAD_ROUNDTRIP=PASS' \
  'GC_LOW01A_NUMERIC_GATE=PASS'; do
  grep -Fq "$marker" "$BUILD/low01a-numeric.txt" || fail "missing numeric marker $marker"
done

for marker in \
  'GC_LOW01A_SOURCE_HBOT_RELATION=PASS' \
  'GC_LOW01A_SOURCE_FLLOWGWL_ACTIVATION=PASS' \
  'GC_LOW01A_SOURCE_RESIDUAL_BRANCH_IDENTITY=PASS' \
  'GC_LOW01A_SOURCE_JACOBIAN_BRANCH_IDENTITY=PASS' \
  'GC_LOW01A_SOURCE_GATE=PASS'; do
  grep -Fq "$marker" "$BUILD/low01a-source.txt" || fail "missing source marker $marker"
done

git diff --check -- \
  integration/research/GC_LOW01A_PREREGISTRATION.json \
  tests/research/test_gc_low01a_below_profile_equivalence.f90 \
  tests/research/test_gc_low01a_source_branch.py \
  tests/research/run_gc_low01a.sh

echo 'GC_LOW01A_QUALIFICATION=PASS'
