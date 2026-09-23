#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm10-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM10_FAIL $*" >&2; exit 1; }

BINDING=src/runtime/mod_fmr_ribasim_management_binding.f90
grep -Fq 'fmr_ribasim_realization_receipt_t' "$BINDING" || fail "typed realization receipt missing"
grep -Fq 'prepare_fmr_hupsel_management_forcing_from_ribasim_receipt' "$BINDING" || fail "typed forcing route missing"
grep -Fq 'FMR_RB_FULL_ALLOCATION_TOLERANCE_CM = 1.0e-6_real64' "$BINDING" || fail "RM09 allocation tolerance not bound"
grep -Fq 'FMR_RB_FULL_SUPPLY_TOLERANCE_CM = 1.0e-4_real64' "$BINDING" || fail "RM09 supply tolerance not bound"
grep -Fq 'FMR_RB_REQUIRED_LEVEL_MARGIN_MULTIPLE = 3.0_real64' "$BINDING" || fail "RM09 level margin not bound"
echo 'RM10_STATIC_AUTHORITY_BINDING=PASS'

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
  src/runtime/mod_fmr_ribasim_management_binding.f90
)
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${SOURCES[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT"     -c tests/ribasim-management/test_rm10_origin_bound_realization_receipt.f90 -o "$OUT/test.o" || fail "compile RM10 test O$opt"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test" || fail "link RM10 O$opt"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  grep -Fq 'RM10 ORIGIN BOUND REALIZATION RECEIPT GATE PASS' "$OUT/output.txt" || fail "final marker O$opt"
  echo "RM10_O${opt}=PASS"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail "O0/O2 output drift"
cat "$BUILD/o0/output.txt"
echo "RM10_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'RM10_O0_O2_IDENTITY=PASS'
echo 'RM10_ORIGIN_BOUND_REALIZATION_RECEIPT_GATE=PASS'
