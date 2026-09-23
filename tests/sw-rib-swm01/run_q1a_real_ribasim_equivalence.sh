#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-sw-rib-swm01-q1a-${GITHUB_RUN_ID:-local}-$$"
RIBASIM_ROOT="${SW_RIB_Q1A_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"
MODEL_ROOT="$RIBASIM_ROOT/generated_testmodels/swap5_sw_rib_swm01_q1a"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "SW_RIB_SWM01_Q1A_FAIL $*" >&2; exit 1; }

gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace   -J "$BUILD" -I "$BUILD"   -c src/process/mod_restricted_fixed_weir_surface_water.f90   -o "$BUILD/fixed_weir.o"
gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace   -J "$BUILD" -I "$BUILD"   -c tests/sw-rib-swm01/emit_q1a_fixed_weir_oracle.f90   -o "$BUILD/emitter.o"
gfortran "$BUILD/fixed_weir.o" "$BUILD/emitter.o" -o "$BUILD/emitter"

"$BUILD/emitter" | tee "$BUILD/oracle.csv"
grep -Fq 'SW_RIB_SWM01_Q1A_ORACLE_EMISSION=PASS' "$BUILD/oracle.csv" || fail "oracle marker missing"
test "$(grep -c '^Q1A_CASE,' "$BUILD/oracle.csv")" -eq 3 || fail "oracle case count"

python3 - "$BUILD/oracle.csv" <<'PY'
import csv, sys
rows=[r for r in csv.reader(open(sys.argv[1])) if r and r[0]=="Q1A_CASE"]
expected=[
    ("C0_NO_DISCHARGE",80.0,-20.0,8.0),
    ("C1_MODERATE_DISCHARGE",130.0,30.0,20.0),
    ("C2_HIGH_DISCHARGE",170.0,70.0,5.0),
]
assert len(rows)==3
for row, exp in zip(rows, expected):
    assert row[1]==exp[0]
    assert abs(float(row[2])-exp[1]) < 1e-12
    assert abs(float(row[3])-exp[2]) < 1e-12
    assert abs(float(row[4])-exp[3]) < 1e-12
print("SW_RIB_SWM01_Q1A_FROZEN_CASES=PASS")
PY

RIBASIM_PIN=e7fc8ade52a4bedeec10e508d2065577f33eb76a
test -d "$RIBASIM_ROOT/.git" || fail "exact Ribasim checkout missing"
ACTUAL_PIN="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL_PIN" = "$RIBASIM_PIN" || fail "Ribasim pin mismatch: $ACTUAL_PIN"
echo "SW_RIB_SWM01_Q1A_RIBASIM_PIN=PASS sha=$ACTUAL_PIN"

(
  cd "$RIBASIM_ROOT"
  pixi run python "$ROOT/tests/sw-rib-swm01/generate_q1a_real_ribasim.py" "$BUILD/oracle.csv" "$MODEL_ROOT"
  pixi run instantiate-julia
  JULIA_NUM_THREADS=2 pixi run julia --startup-file=no --project=.     "$ROOT/tests/sw-rib-swm01/q1a_real_ribasim_equivalence.jl"     "$BUILD/oracle.csv" "$MODEL_ROOT"
) > "$BUILD/ribasim.txt" 2>&1 || {
  cat "$BUILD/ribasim.txt" >&2
  fail "real Ribasim Q1A execution"
}

cat "$BUILD/ribasim.txt"
grep -Fq 'SW_RIB_SWM01_Q1A_REAL_RIBASIM_EXTERNAL_OWNER_EQUIVALENCE=PASS' "$BUILD/ribasim.txt" || fail "final marker missing"
echo 'SW_RIB_SWM01_Q1A_GATE=PASS'
