#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ross02-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

TX=src/transaction/mod_transaction_reference.f90
CONTRACTS=src/runtime/mod_canonical_contracts.f90
RUNTIME=src/runtime/mod_canonical_interval_runtime.f90
POLICY=src/runtime/mod_rossfast_d3r_execution_policy.f90
BINDING=src/runtime/mod_rossfast_d3r_model_binding.f90
TEST=tests/ross/test_ross02_rossfast_d3r_model_binding.f90

# F-ROSS02 inherits the admitted F-CI67 transaction/runtime/policy surface.
# Any change to these authorities requires separate requalification instead of
# silently widening this production-binding result.
test "$(git rev-parse HEAD:$TX)" = d5a71a526efaebd82054580c3186f8e3545db331
test "$(git rev-parse HEAD:$CONTRACTS)" = 3cbb81b25626e6574ae83416f088dc52882f91fc
test "$(git rev-parse HEAD:$RUNTIME)" = b12327aa6e77bdbf4586fe0bed82cf0e7704f237
test "$(git rev-parse HEAD:$POLICY)" = a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9

grep -Fq 'type, extends(canonical_physical_model_t), public :: rossfast_d3r_model_t' "$BINDING"
grep -Fq 'class(rossfast_d3r_trial_kernel_t), intent(in) :: self' "$BINDING"
grep -Fq 'TX_TEMPORAL_MODEL_CERTIFICATE' "$BINDING"
grep -Fq 'ROSSFAST_D3R_TEMPORAL_RESOLUTION_FLOOR = 1.0e-10_real64' "$BINDING"
grep -Fq 'ROSSFAST_D3R_TEMPORAL_ACCURACY_TOLERANCE = 1.0e-5_real64' "$BINDING"
grep -Fq "case('B01')" "$BINDING"
grep -Fq "case('B12')" "$BINDING"
grep -Fq "case('O01')" "$BINDING"
grep -Fq "case('O05')" "$BINDING"
grep -Fq "case('O14')" "$BINDING"
grep -Fq "case('O18')" "$BINDING"

WARN=(-Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -fopenmp)
for opt in o0 o2; do
  flag=-O0
  [[ "$opt" == o2 ]] && flag=-O2
  moddir="$BUILD/$opt"

  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$TX" -o "$moddir/tx.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$CONTRACTS" -o "$moddir/contracts.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$RUNTIME" -o "$moddir/runtime.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$POLICY" -o "$moddir/policy.o"
  gfortran "${WARN[@]}" "$flag" -std=f2008 -J "$moddir" -I "$moddir" -c "$BINDING" -o "$moddir/binding.o"
  gfortran "${WARN[@]}" "$flag" -std=f2018 -J "$moddir" -I "$moddir" -c "$TEST" -o "$moddir/test.o"
  gfortran -fopenmp "$moddir/tx.o" "$moddir/contracts.o" "$moddir/runtime.o" "$moddir/policy.o" \
       "$moddir/binding.o" "$moddir/test.o" -o "$moddir/test"
  "$moddir/test" > "$moddir/output.txt"
  grep -Fq 'ROSS02_ROSSFAST_D3R_MODEL_BINDING_GATE PASS' "$moddir/output.txt"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo "ROSS02_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'ROSS02_ROSSFAST_D3R_MODEL_BINDING=PASS'
