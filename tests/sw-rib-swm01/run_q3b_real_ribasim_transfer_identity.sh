#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

RIBASIM_ROOT="${SW_RIB_Q3B_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"
MODEL_ROOT="$RIBASIM_ROOT/generated_testmodels/swap5_sw_rib_swm01_q3b"
RIBASIM_PIN=e7fc8ade52a4bedeec10e508d2065577f33eb76a

fail(){ echo "SW_RIB_SWM01_Q3B_FAIL $*" >&2; exit 1; }

python3 tests/sw-rib-swm01/test_q3b_transfer_ledger.py | tee /tmp/sw-rib-swm01-q3b-ledger.txt
grep -Fq 'SW_RIB_SWM01_Q3B_TRANSFER_IDENTITY_LEDGER=PASS' /tmp/sw-rib-swm01-q3b-ledger.txt || fail "ledger marker missing"

test -d "$RIBASIM_ROOT/.git" || fail "exact Ribasim checkout missing"
ACTUAL_PIN="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL_PIN" = "$RIBASIM_PIN" || fail "Ribasim pin mismatch: $ACTUAL_PIN"
echo "SW_RIB_SWM01_Q3B_RIBASIM_PIN=PASS sha=$ACTUAL_PIN"

(
  cd "$RIBASIM_ROOT"
  pixi run python "$ROOT/tests/sw-rib-swm01/generate_q3b_real_ribasim.py" "$MODEL_ROOT"
  pixi run instantiate-julia
  JULIA_NUM_THREADS=2 pixi run julia --startup-file=no --project=.     "$ROOT/tests/sw-rib-swm01/q3b_real_ribasim_transfer_identity.jl" "$MODEL_ROOT"
) > /tmp/sw-rib-swm01-q3b.txt 2>&1 || {
  cat /tmp/sw-rib-swm01-q3b.txt >&2
  fail "real Ribasim Q3B execution"
}

cat /tmp/sw-rib-swm01-q3b.txt
grep -Fq 'SW_RIB_SWM01_Q3B_REAL_RIBASIM_TRANSFER_IDENTITIES=PASS' /tmp/sw-rib-swm01-q3b.txt || fail "final marker missing"
test "$(grep -c '^SW_RIB_SWM01_Q3B_CASE_PASS=' /tmp/sw-rib-swm01-q3b.txt)" -eq 4 || fail "case count"
grep -Fq 'COUPLING_DISPOSITION=RECOMPOSITION_REQUIRED' /tmp/sw-rib-swm01-q3b.txt || fail "availability recomposition marker missing"
echo 'SW_RIB_SWM01_Q3B_GATE=PASS'
