#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm07-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM07_FAIL $*" >&2; exit 1; }

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
  src/runtime/mod_fmr_hupsel_management_demand_receipt.f90
)
TEST=tests/ribasim-management/test_rm07_demand_receipt.f90

python3 - <<'PY'
from pathlib import Path
p=Path("src/runtime/mod_fmr_hupsel_management_demand_receipt.f90").read_text()
low=p.lower()
assert "allocated_depth_cm" not in low
assert "supplied_depth_cm" not in low
assert "evaluate_tcs1_dcs2_sprinkling_interval" in p
assert "management_lineage_id" in p
assert "management_origin_revision" in p
assert "crop_origin_revision" in p
print("RM07_STATIC_READ_ONLY_DEMAND_SEAM=PASS")
PY

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o" || fail "compile test O$opt"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test" || fail "link O$opt"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  grep -Fq 'RM07 DEMAND RECEIPT QUALIFICATION PASS' "$OUT/output.txt" || fail "missing final marker O$opt"
  echo "RM07_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail "O0/O2 output drift"
cat "$BUILD/o0/output.txt"
echo "RM07_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'RM07_O0_O2_IDENTITY=PASS'
echo 'RM07_DEMAND_RECEIPT_GATE=PASS'
