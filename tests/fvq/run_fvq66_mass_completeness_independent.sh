#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fvq66-mass-${GITHUB_RUN_ID:-local}-${FVQ66_TAG:-candidate}"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

SRC="${FVQ66_TRANSACTION_SOURCE:-$ROOT/src/transaction/mod_transaction_reference.f90}"
TEST="$ROOT/tests/fvq/test_fvq66_mass_completeness_attack.f90"
TAG="${FVQ66_TAG:-candidate}"
FLAGS=(-std=f2008 -Wall -Wextra -ffree-line-length-none -fcheck=all -fbacktrace)

echo "FVQ66_COMPILER=$(gfortran --version | head -n 1)"
echo "FVQ66_SOURCE=$SRC"
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  gfortran "${FLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" \
    "$SRC" "$TEST" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt"
  grep -Fq 'FVQ66_ATTACK_MATRIX=PASS' "$OUT/out.txt"
  grep -Fq 'FVQ66_ZERO_RESIDUAL_INCOMPLETE_FAIL_CLOSED=PASS' "$OUT/out.txt"
  grep -Fq 'FVQ66_NONZERO_MISSING_MASK_FAIL_CLOSED=PASS' "$OUT/out.txt"
  grep -Fq 'FVQ66_NONFINITE_MASS_FAIL_CLOSED=PASS' "$OUT/out.txt"
  grep -Fq 'FVQ66_REJECTED_COMMITTED_STATE_BITWISE_IMMUTABLE=PASS' "$OUT/out.txt"
  grep -Fq 'FVQ66_RETRY_NO_PHYSICAL_ACCUMULATION=PASS' "$OUT/out.txt"
  grep -Fq 'FVQ66_RETRY_EXHAUSTION_FAIL_CLOSED=PASS' "$OUT/out.txt"
  grep -Fq 'FVQ66_INCOMPLETE_CANNOT_MATERIALIZE_ACCEPTED_CANDIDATE=PASS' "$OUT/out.txt"
  grep -Fq 'FVQ66_NORMAL_COMPLETE_LEDGER_PRESERVATION=PASS' "$OUT/out.txt"
  grep -Fq 'FVQ66_ALTERNATIVE_SOLVER_INCOMPLETE_FAIL_CLOSED=PASS' "$OUT/out.txt"
  grep -Fq 'FVQ66_SECOND_HALF_INCOMPLETE_FAIL_CLOSED=PASS' "$OUT/out.txt"
  grep -Fq 'FVQ66_MASS_RESULT_TRANSPORT=PASS' "$OUT/out.txt"
  grep -Fq 'FVQ66_GENERIC_TIME_TRANSACTION=PASS' "$OUT/out.txt"
  echo "FVQ66_${TAG^^}_O${opt}=PASS"
done
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"
echo "FVQ66_${TAG^^}_O0_O2_IDENTITY=PASS"
cat "$BUILD/o0/out.txt"
