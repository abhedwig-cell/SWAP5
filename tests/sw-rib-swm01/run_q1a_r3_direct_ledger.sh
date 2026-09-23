#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-sw-rib-swm01-q1a-r3l-${GITHUB_RUN_ID:-local}-$$"
RIBASIM_ROOT="${SW_RIB_Q1A_R3L_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"
MODEL_ROOT="$RIBASIM_ROOT/generated_testmodels/swap5_sw_rib_swm01_q1a_r3l"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "SW_RIB_SWM01_Q1A_R3L_FAIL $*" >&2; exit 1; }

gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace \
  -J "$BUILD" -I "$BUILD" \
  -c src/process/mod_restricted_fixed_weir_surface_water.f90 -o "$BUILD/fixed_weir.o"
gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace \
  -J "$BUILD" -I "$BUILD" \
  -c tests/sw-rib-swm01/emit_q1a_fixed_weir_oracle.f90 -o "$BUILD/emitter.o"
gfortran "$BUILD/fixed_weir.o" "$BUILD/emitter.o" -o "$BUILD/emitter"
"$BUILD/emitter" | tee "$BUILD/oracle.csv"
grep -Fq 'SW_RIB_SWM01_Q1A_ORACLE_EMISSION=PASS' "$BUILD/oracle.csv" || fail "oracle marker missing"

RIBASIM_PIN=e7fc8ade52a4bedeec10e508d2065577f33eb76a
test -d "$RIBASIM_ROOT/.git" || fail "exact Ribasim checkout missing"
ACTUAL_PIN="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL_PIN" = "$RIBASIM_PIN" || fail "Ribasim pin mismatch: $ACTUAL_PIN"

(
  cd "$RIBASIM_ROOT"
  pixi run python "$ROOT/tests/sw-rib-swm01/generate_q1a_r3_real_ribasim.py" "$BUILD/oracle.csv" "$MODEL_ROOT"
  pixi run instantiate-julia
  JULIA_NUM_THREADS=2 pixi run julia --startup-file=no --project=. \
    "$ROOT/tests/sw-rib-swm01/q1a_r3_direct_ledger.jl" "$BUILD/oracle.csv" "$MODEL_ROOT"
) > "$BUILD/r3l.txt" 2>&1 || {
  cat "$BUILD/r3l.txt" >&2
  fail "R3 direct-ledger execution"
}

cat "$BUILD/r3l.txt"
grep -Fq 'SW_RIB_SWM01_Q1A_R3_DIRECT_LEDGER=PASS' "$BUILD/r3l.txt" || fail "final marker missing"
test "$(grep -c '^SW_RIB_SWM01_Q1A_R3L_CASE_PASS=' "$BUILD/r3l.txt")" -eq 3 || fail "case pass count"
echo 'SW_RIB_SWM01_Q1A_R3L_GATE=PASS'
