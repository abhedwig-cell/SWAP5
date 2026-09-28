#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=1759caebb7ca3bd62bbee65d9319f5d71d3e73f5
TARGET=tests/verification/test_bofek00_dynamic_top_correction.f90
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-bofek00-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_BOFEK00_CORRECTION_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after BOFEK00 preregistration: $LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail "candidate not descendant of preregistered base"

python3 - <<'PY'
from pathlib import Path
head=Path("src/legacy/b1_10_port/headcalc.f90").read_text()
top=Path("src/solver/mod_b110_dynamic_top_boundary_provider.f90").read_text()
contract=Path("src/solver/mod_soil_water_solver_contract.f90").read_text()
adapter=Path("src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90").read_text()
assert "current_runoff = restricted_linear_runoff_depth(request%candidate_ponding_depth_cm, request)" not in top
assert "surface_head_derivative_available" in top
assert "surface_head_dpressure_head_top" in top
assert "surface_head_derivative_available" in contract
assert "surface_head_dpressure_head_top" in adapter
assert "1.0d0-provider_dynamic_top_result%surface_head_dpressure_head_top" in head
print("F_PE_BOFEK00_CORRECTION_SOURCE_SHAPE=PASS")
PY

stub="$BUILD/stubs_n16.f90"
python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes 16

for opt in 0 2; do
  out="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$TARGET" \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --external-source src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90 \
    --build "$out" --opt "$opt"
  "$out/rom0_test" > "$BUILD/result_o$opt.txt" 2>&1 || {
    cat "$BUILD/result_o$opt.txt" >&2
    fail "corrected provider/headcalc gate O$opt"
  }
  cat "$BUILD/result_o$opt.txt"
  grep -Fq 'F_PE_BOFEK00_DYNAMIC_TOP_CORRECTION=PASS' "$BUILD/result_o$opt.txt" || fail "missing PASS O$opt"
done
cmp "$BUILD/result_o0.txt" "$BUILD/result_o2.txt" || fail "O0/O2 behavioral drift"

echo "F_PE_BOFEK00_CORRECTION_GATE=PASS"
