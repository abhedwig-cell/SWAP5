#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

RIBASIM_ROOT="${SW_RIB_Q2B1_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"
MODEL_ROOT="$RIBASIM_ROOT/generated_testmodels/swap5_sw_rib_swm01_q2b1"
RIBASIM_PIN=e7fc8ade52a4bedeec10e508d2065577f33eb76a
fail(){ echo "SW_RIB_SWM01_Q2B1_FAIL $*" >&2; exit 1; }

test -d "$RIBASIM_ROOT/.git" || fail "exact Ribasim checkout missing"
ACTUAL_PIN="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL_PIN" = "$RIBASIM_PIN" || fail "Ribasim pin mismatch: $ACTUAL_PIN"
echo "SW_RIB_SWM01_Q2B1_RIBASIM_PIN=PASS sha=$ACTUAL_PIN"

(
  cd "$RIBASIM_ROOT"
  pixi run python "$ROOT/tests/sw-rib-swm01/generate_q2b1_real_ribasim.py" "$MODEL_ROOT"
  pixi run instantiate-julia
  JULIA_NUM_THREADS=2 pixi run julia --startup-file=no --project=.     "$ROOT/tests/sw-rib-swm01/q2b1_real_ribasim_band.jl" "$MODEL_ROOT"
) > /tmp/sw-rib-swm01-q2b1.txt 2>&1 || {
  cat /tmp/sw-rib-swm01-q2b1.txt >&2
  fail "real Ribasim Q2B1 execution"
}

cat /tmp/sw-rib-swm01-q2b1.txt
grep -Fq 'SW_RIB_SWM01_Q2B1_REAL_RIBASIM_BAND=PASS' /tmp/sw-rib-swm01-q2b1.txt || fail "final marker missing"
test "$(grep -c '^SW_RIB_SWM01_Q2B1_CASE_PASS=' /tmp/sw-rib-swm01-q2b1.txt)" -eq 5 || fail "case count"
echo 'SW_RIB_SWM01_Q2B1_GATE=PASS'
