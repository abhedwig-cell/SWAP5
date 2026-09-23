#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm09-${GITHUB_RUN_ID:-local}-$$"
RIBASIM_ROOT="${RM09_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"
MODEL_DIR="$RIBASIM_ROOT/generated_testmodels/swap5_rm09"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM09_FAIL $*" >&2; exit 1; }

RIBASIM_PIN=e7fc8ade52a4bedeec10e508d2065577f33eb76a
test -d "$RIBASIM_ROOT/.git" || fail "Ribasim product-release checkout missing"
ACTUAL_PIN="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL_PIN" = "$RIBASIM_PIN" || fail "Ribasim pin mismatch: $ACTUAL_PIN"
echo "RM09_RIBASIM_PRODUCT_PIN=PASS sha=$ACTUAL_PIN"

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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT"     -c tests/ribasim-management/test_rm09_swap_ribasim_bridge.f90 -o "$OUT/test.o" || fail "compile RM09 oracle O$opt"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test" || fail "link RM09 oracle O$opt"
  "$OUT/test" request > "$OUT/request.txt" 2>&1 || { cat "$OUT/request.txt" >&2; fail "SWAP request O$opt"; }
  grep -Fq 'RM09_SWAP_READ_ONLY_REQUEST=PASS' "$OUT/request.txt" || fail "request marker O$opt"
done

cmp "$BUILD/o0/request.txt" "$BUILD/o2/request.txt" || fail "O0/O2 SWAP request drift"
REQUEST_CM="$(awk -F= '/^RM09_SWAP_REQUEST_DEPTH_CM=/{gsub(/[[:space:]]/,"",$2); print $2}' "$BUILD/o0/request.txt")"
test -n "$REQUEST_CM" || fail "could not parse SWAP request depth"
python3 - "$REQUEST_CM" <<'PY'
import math,sys
x=float(sys.argv[1])
assert math.isclose(x,2.0,rel_tol=0.0,abs_tol=1e-12), x
PY
cat "$BUILD/o0/request.txt"
echo "RM09_SWAP_REQUEST_O0_O2_IDENTITY=PASS"

(
  cd "$RIBASIM_ROOT"
  pixi run python "$ROOT/tests/ribasim-management/generate_rm09_real_ribasim.py" "$MODEL_DIR" "$REQUEST_CM"
  pixi run instantiate-julia
  JULIA_NUM_THREADS=2 pixi run julia --startup-file=no --project=.     "$ROOT/tests/ribasim-management/rm09_real_ribasim_bridge.jl"     "$MODEL_DIR/ribasim.toml" "$REQUEST_CM"
) > "$BUILD/ribasim.txt" 2>&1 || { cat "$BUILD/ribasim.txt" >&2; fail "real Ribasim aligned fixture"; }

cat "$BUILD/ribasim.txt"
grep -Fq 'RM09 REAL RIBASIM ALIGNED FIXTURE PASS' "$BUILD/ribasim.txt" || fail "missing real Ribasim pass marker"
ALLOCATED_CM="$(awk -F= '/^RM09_RIBASIM_ALLOCATED_DEPTH_CM=/{gsub(/[[:space:]]/,"",$2); print $2}' "$BUILD/ribasim.txt")"
SUPPLIED_CM="$(awk -F= '/^RM09_RIBASIM_SUPPLIED_DEPTH_CM=/{gsub(/[[:space:]]/,"",$2); print $2}' "$BUILD/ribasim.txt")"
test -n "$ALLOCATED_CM" -a -n "$SUPPLIED_CM" || fail "could not parse Ribasim allocation/supply"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  "$OUT/test" consume "$ALLOCATED_CM" "$SUPPLIED_CM" > "$OUT/consume.txt" 2>&1 || {
    cat "$OUT/consume.txt" >&2
    fail "SWAP consume O$opt"
  }
  grep -Fq 'RM09 SWAP SIDE REAL RIBASIM RECEIPT CONSUMPTION PASS' "$OUT/consume.txt" || fail "consume marker O$opt"
done
cmp "$BUILD/o0/consume.txt" "$BUILD/o2/consume.txt" || fail "O0/O2 SWAP consumption drift"
cat "$BUILD/o0/consume.txt"

echo "RM09_SWAP_CONSUMPTION_O0_O2_IDENTITY=PASS"
echo "RM09_REAL_RIBASIM_ALIGNED_GATE=PASS"
