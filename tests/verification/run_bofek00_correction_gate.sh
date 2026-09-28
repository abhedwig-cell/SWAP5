#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

AUTH=0b67e2af993f16e9d1678b70cacfe9b164954140
TARGET=tests/verification/test_bofek00_dynamic_top_correction.f90
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-bofek00-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_BOFEK00_CORRECTION_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags --depth=1 origin work/f-pe-bofek00-wet-regime-authority
git merge-base --is-ancestor "$AUTH" HEAD || fail "correction candidate lost preregistered reproduction authority"

python3 - <<'PY'
from pathlib import Path
head=Path("src/legacy/b1_10_port/headcalc.f90").read_text()
top=Path("src/solver/mod_b110_dynamic_top_boundary_provider.f90").read_text()
contract=Path("src/solver/mod_soil_water_solver_contract.f90").read_text()
adapter=Path("src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90").read_text()
assert "surface_head_dpressure_available" in contract
assert "provider_dynamic_top_result%surface_head_dpressure" in head
assert "request%runoff_resistance_day >= B110_DYN_TOP_MIN_LINEAR_RSRO_DAY" in top
assert "result%surface_head_dpressure = p1*p2" in top
assert "result%surface_head_dpressure = b110_result%surface_head_dpressure" in adapter
print("F_PE_BOFEK00_CORRECTION_SOURCE_SHAPE=PASS")
PY

stub="$BUILD/stubs_n16.f90"
python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes 16 --dz-cm 10
for opt in 0 2; do
  out="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$TARGET" --build "$out" --opt "$opt"
  "$out/rom0_test" > "$BUILD/result_o$opt.txt" 2>&1 || {
    cat "$BUILD/result_o$opt.txt" >&2
    fail "Fortran correction gate O$opt"
  }
  grep -Fq 'F_PE_BOFEK00_DYNAMIC_TOP_CORRECTION=PASS' "$BUILD/result_o$opt.txt" || fail "missing correction pass O$opt"
done
cmp "$BUILD/result_o0.txt" "$BUILD/result_o2.txt" || fail "O0/O2 corrected wet-boundary drift"
cat "$BUILD/result_o2.txt"
echo "F_PE_BOFEK00_CORRECTION_GATE=PASS"
