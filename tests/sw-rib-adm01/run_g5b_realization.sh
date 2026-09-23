#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
RIBASIM_ROOT="${SW_RIB_ADM01_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"
MODEL_ROOT="$RIBASIM_ROOT/generated_testmodels/swap5_sw_rib_adm01_g5b"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-sw-rib-adm01-g5b-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
PIN=e7fc8ade52a4bedeec10e508d2065577f33eb76a
test -d "$RIBASIM_ROOT/.git"
test "$(git -C "$RIBASIM_ROOT" rev-parse HEAD)" = "$PIN"
echo "SW_RIB_ADM01_G5B_RIBASIM_PIN=PASS sha=$PIN"

gfortran -std=f2008 -Wall -Wextra -Werror   src/runtime/mod_external_surface_water_transaction.f90   tests/sw-rib-adm01/g5b_transaction_bridge.f90   -o "$BUILD/bridge"

(
 cd "$RIBASIM_ROOT"
 pixi run python "$ROOT/tests/sw-rib-adm01/generate_g5b_real_ribasim.py" "$MODEL_ROOT"
 pixi run instantiate-julia
 JULIA_NUM_THREADS=2 pixi run julia --startup-file=no --project=.    "$ROOT/tests/sw-rib-adm01/g5b_realization.jl" "$MODEL_ROOT"
) > "$BUILD/ribasim.txt" 2>&1

cat "$BUILD/ribasim.txt"
grep -Fq 'SW_RIB_ADM01_G5B_REAL_RIBASIM_REALIZATION=PASS' "$BUILD/ribasim.txt"
python3 tests/sw-rib-adm01/verify_g5b_receipts.py "$BUILD/ribasim.txt" "$BUILD/bridge" | tee "$BUILD/bridge.txt"
grep -Fq 'SW_RIB_ADM01_G5B_RECEIPT_TO_PRODUCTION_TRANSACTION=PASS' "$BUILD/bridge.txt"
echo 'SW_RIB_ADM01_G5B_GATE=PASS'
