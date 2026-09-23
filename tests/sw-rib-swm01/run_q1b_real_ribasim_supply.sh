#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

RIBASIM_ROOT="${SW_RIB_Q1B_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"
MODEL_ROOT="$RIBASIM_ROOT/generated_testmodels/swap5_sw_rib_swm01_q1b"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-sw-rib-swm01-q1b-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "SW_RIB_SWM01_Q1B_FAIL $*" >&2; exit 1; }

RIBASIM_PIN=e7fc8ade52a4bedeec10e508d2065577f33eb76a
test -d "$RIBASIM_ROOT/.git" || fail "exact Ribasim checkout missing"
ACTUAL_PIN="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL_PIN" = "$RIBASIM_PIN" || fail "Ribasim pin mismatch: $ACTUAL_PIN"
echo "SW_RIB_SWM01_Q1B_RIBASIM_PIN=PASS sha=$ACTUAL_PIN"

(
  cd "$RIBASIM_ROOT"
  pixi run python "$ROOT/tests/sw-rib-swm01/generate_q1b_real_ribasim.py" "$MODEL_ROOT"
  pixi run instantiate-julia
  JULIA_NUM_THREADS=2 pixi run julia --startup-file=no --project=. \
    "$ROOT/tests/sw-rib-swm01/q1b_real_ribasim_supply.jl" "$MODEL_ROOT"
) > "$BUILD/q1b.txt" 2>&1 || {
  cat "$BUILD/q1b.txt" >&2
  fail "real Ribasim Q1B execution"
}

cat "$BUILD/q1b.txt"
grep -Fq 'SW_RIB_SWM01_Q1B_REAL_RIBASIM_SUPPLY=PASS' "$BUILD/q1b.txt" || fail "final marker missing"
test "$(grep -c '^SW_RIB_SWM01_Q1B_CASE_PASS=' "$BUILD/q1b.txt")" -eq 3 || fail "case pass count"
echo 'SW_RIB_SWM01_Q1B_GATE=PASS'
