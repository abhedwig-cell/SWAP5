#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci14-gate-$$"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/o0" "$BUILD/o2"

python "$ROOT/tools/fci/fci14_reference_temporal_policy_gate.py"

TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
TRIAL="$ROOT/src/adapter/mod_b1_10_trial_mass.f90"
INTERVAL="$ROOT/src/adapter/mod_b1_10_interval_seam.f90"
BASE="$ROOT/src/adapter/mod_b1_10_transaction_binding.f90"
MASS="$ROOT/src/adapter/mod_b1_10_mass_seam.f90"
TEMPORAL="$ROOT/src/adapter/mod_b1_10_temporal_characterization.f90"
FCI12_EXEC="$ROOT/src/adapter/mod_b1_10_physical_interval_executor.f90"
FCI12_REF="$ROOT/src/adapter/mod_b1_10_reference_model.f90"
STATUS="$ROOT/src/adapter/mod_b1_10_trial_status.f90"
FCI13_EXEC="$ROOT/src/adapter/mod_b1_10_recoverable_interval_executor.f90"
FCI13_REF="$ROOT/src/adapter/mod_b1_10_recoverable_reference_model.f90"
POLICY="$ROOT/src/adapter/mod_b1_10_reference_temporal_policy.f90"
MODEL="$ROOT/src/adapter/mod_b1_10_reference_policy_candidate_model.f90"
STUBS="$ROOT/tests/fci/fci14_reference_policy_stubs.f90"
TEST="$ROOT/tests/fci/test_fci14_reference_temporal_policy.f90"

for opt in 0 2; do
  O="$BUILD/o$opt"
  FLAGS=(-O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none -J "$O" -I "$O")
  gfortran "${FLAGS[@]}" -c "$TX" -o "$O/transaction.o"
  gfortran "${FLAGS[@]}" -c "$CONTRACTS" -o "$O/contracts.o"
  gfortran "${FLAGS[@]}" -c "$WORKER" -o "$O/worker.o"
  gfortran "${FLAGS[@]}" -c "$TRIAL" -o "$O/trial_mass.o"
  gfortran "${FLAGS[@]}" -c "$INTERVAL" -o "$O/interval.o"
  gfortran "${FLAGS[@]}" -c "$STUBS" -o "$O/stubs.o"
  gfortran "${FLAGS[@]}" -c "$BASE" -o "$O/base_binding.o"
  gfortran "${FLAGS[@]}" -c "$MASS" -o "$O/mass_seam.o"
  gfortran "${FLAGS[@]}" -c "$TEMPORAL" -o "$O/temporal.o"
  gfortran "${FLAGS[@]}" -c "$FCI12_EXEC" -o "$O/fci12_executor.o"
  gfortran "${FLAGS[@]}" -c "$FCI12_REF" -o "$O/fci12_reference.o"
  gfortran "${FLAGS[@]}" -c "$STATUS" -o "$O/status.o"
  gfortran "${FLAGS[@]}" -c "$FCI13_EXEC" -o "$O/fci13_executor.o"
  gfortran "${FLAGS[@]}" -c "$FCI13_REF" -o "$O/fci13_reference.o"
  gfortran "${FLAGS[@]}" -c "$POLICY" -o "$O/policy.o"
  gfortran "${FLAGS[@]}" -c "$MODEL" -o "$O/model.o"
  gfortran "${FLAGS[@]}" -c "$TEST" -o "$O/test.o"
  gfortran -O$opt -o "$O/test_policy" \
    "$O/transaction.o" "$O/contracts.o" "$O/worker.o" "$O/trial_mass.o" "$O/interval.o" \
    "$O/stubs.o" "$O/base_binding.o" "$O/mass_seam.o" "$O/temporal.o" \
    "$O/fci12_executor.o" "$O/fci12_reference.o" "$O/status.o" "$O/fci13_executor.o" "$O/fci13_reference.o" \
    "$O/policy.o" "$O/model.o" "$O/test.o"
  "$O/test_policy" > "$O/pass.log"
  grep -q 'FCI14_REFERENCE_TEMPORAL_POLICY PASS' "$O/pass.log"
done

cmp "$BUILD/o0/pass.log" "$BUILD/o2/pass.log"
echo FCI14_GATE_PASS
