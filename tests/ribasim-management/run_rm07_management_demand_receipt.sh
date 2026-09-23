#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm07-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM07_FAIL $*" >&2; exit 1; }

SRC=src/runtime/mod_fmr_hupsel_management_transaction.f90
TEST=tests/ribasim-management/test_rm07_management_demand_receipt.f90

grep -Fq 'derive_fmr_hupsel_management_demand_receipt' "$SRC" || fail "missing demand derivation seam"
grep -Fq 'type, public :: fmr_hupsel_management_demand_receipt_t' "$SRC" || fail "missing typed demand receipt"
grep -Fq 'kernel_checkpoint_t' "$SRC" || fail "receipt not checkpoint-bound"
if awk '/subroutine derive_fmr_hupsel_management_demand_receipt/,/end subroutine derive_fmr_hupsel_management_demand_receipt/' "$SRC" | grep -Eiq 'allocated_depth|supplied_depth'; then
  fail "demand derivation depends on allocation/supply"
fi
echo 'RM07_STATIC_CAUSAL_SEPARATION=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -Wno-error=function-elimination -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
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
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${SOURCES[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o" || fail "compile test O$opt"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test" || fail "link O$opt"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  grep -Fq 'RM07 MANAGEMENT DEMAND RECEIPT GATE PASS' "$OUT/output.txt" || fail "missing final marker O$opt"
  echo "RM07_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail "O0/O2 output drift"
cat "$BUILD/o0/output.txt"
echo "RM07_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'RM07_O0_O2_IDENTITY=PASS'
echo 'RM07_DEMAND_RECEIPT_GATE=PASS'
