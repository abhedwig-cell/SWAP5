#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fvq67-mass-${GITHUB_RUN_ID:-local}-${FVQ67_TAG:-candidate}"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

SRC="${FVQ67_TRANSACTION_SOURCE:-$ROOT/src/transaction/mod_transaction_reference.f90}"
TEST="$ROOT/tests/fvq/test_fvq67_mass_completeness_attack.f90"
TAG="${FVQ67_TAG:-candidate}"
FLAGS=(-std=f2008 -Wall -Wextra -ffree-line-length-none -fcheck=all -fbacktrace)

echo "FVQ67_COMPILER=$(gfortran --version | head -n 1)"
echo "FVQ67_SOURCE=$SRC"
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  gfortran "${FLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" "$SRC" "$TEST" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt"
  for marker in \
    FVQ67_ATTACK_MATRIX=PASS \
    FVQ67_ZERO_RESIDUAL_INCOMPLETE_FAIL_CLOSED=PASS \
    FVQ67_NONZERO_MISSING_MASK_FAIL_CLOSED=PASS \
    FVQ67_COMPLETE_IN_TOLERANCE_ACCEPTS=PASS \
    FVQ67_COMPLETE_OUTSIDE_TOLERANCE_REJECTS=PASS \
    FVQ67_NONFINITE_MASS_FAIL_CLOSED=PASS \
    FVQ67_REJECTED_COMMITTED_STATE_BITWISE_IMMUTABLE=PASS \
    FVQ67_RETRY_NO_PHYSICAL_ACCUMULATION=PASS \
    FVQ67_RETRY_EXHAUSTION_FAIL_CLOSED=PASS \
    FVQ67_INCOMPLETE_CANNOT_MATERIALIZE_ACCEPTED_CANDIDATE=PASS \
    FVQ67_NORMAL_COMPLETE_LEDGER_PRESERVATION=PASS \
    FVQ67_ALTERNATIVE_SOLVER_INCOMPLETE_FAIL_CLOSED=PASS \
    FVQ67_SECOND_HALF_INCOMPLETE_FAIL_CLOSED=PASS \
    FVQ67_MASS_RESULT_TRANSPORT=PASS \
    FVQ67_GENERIC_TIME_TRANSACTION=PASS; do
    grep -Fq "$marker" "$OUT/out.txt"
  done
  echo "FVQ67_${TAG^^}_O${opt}=PASS"
done
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"
echo "FVQ67_${TAG^^}_O0_O2_IDENTITY=PASS"
cat "$BUILD/o0/out.txt"
