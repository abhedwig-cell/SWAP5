#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm06-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM06_FAIL $*" >&2; exit 1; }

SRC=src/runtime/mod_fmr_hupsel_management_transaction.f90
TEST=tests/ribasim-management/test_rm06_management_transaction.f90
[[ -f "$SRC" && -f "$TEST" ]] || fail "missing source or test"

grep -Fq 'type, extends(transaction_state_t), public :: fmr_hupsel_management_state_t' "$SRC" || fail "missing typed management state"
grep -Fq 'allocated_depth_cm' "$SRC" || fail "missing allocation object"
grep -Fq 'supplied_depth_cm' "$SRC" || fail "missing supplied object"
grep -Fq 'FMR_RM_PARTIAL_SUPPLY_NOT_ADMITTED' "$SRC" || fail "missing bounded partial-supply disposition"
grep -Fq 'outcome%mass_in = 0.0_real64' "$SRC" || fail "management owner must not duplicate physical water ledger"
grep -Fq 'Water mass remains owned' "$SRC" || fail "missing ledger ownership note"
echo 'RM06_STATIC_OWNERSHIP_CONTRACT=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/process/mod_tcs1_dcs2_sprinkling_irrigation_process.f90
  src/process/mod_rutter_interception_process.f90
  src/runtime/mod_fmr_hupsel_management_transaction.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o" || fail "compile test O$opt"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test" || fail "link O$opt"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }

  for marker in \
    'RM06_CANDIDATE_NONMUTATING=PASS' \
    'RM06_REJECT_RETRY_IRRIGATION_IDENTITY=PASS' \
    'RM06_REJECT_RETRY_RUTTER_IDENTITY=PASS' \
    'RM06_REJECT_RETRY_OBSERVATION_IDENTITY=PASS' \
    'RM06_REQUEST_ALLOCATION_SUPPLY_DISTINCT=PASS' \
    'RM06_GROSS_NET_APPLICATION_DISTINCT=PASS' \
    'RM06_EXACTLY_ONCE_COMMIT=PASS' \
    'RM06_RESTART_PERSISTENCE_IDENTITY=PASS' \
    'RM06_SUPPLY_LE_ALLOCATION=PASS' \
    'RM06_PARTIAL_SUPPLY_FAIL_CLOSED=PASS' \
    'RM06 MANAGEMENT TRANSACTION QUALIFICATION PASS'; do
      grep -Fq "$marker" "$OUT/output.txt" || fail "missing marker O$opt: $marker"
  done
  echo "RM06_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail "O0/O2 output drift"
cat "$BUILD/o0/output.txt"
echo "RM06_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'RM06_O0_O2_IDENTITY=PASS'
echo 'RM06_TRANSACTION_GATE=PASS'
