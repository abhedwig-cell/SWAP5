#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm08c1r-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=edff81f4c784ec62bfbee5f131d7c0c71eba0d58
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "src/process/mod_drainage_tabulated_response.f90" ]] || {
  echo 'FPM08C1R_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FPM08C1R_PRODUCTION_DELTA_SINGLE_PROCESS_MODULE=PASS'

if git diff --name-only "$BASE" -- reference | grep -q .; then
  echo 'FPM08C1R_REFERENCE_DELTA=FAIL' >&2
  exit 1
fi
echo 'FPM08C1R_REFERENCE_DELTA_NONE=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/process/mod_drainage_tabulated_response.f90').read_text()
assert 'DRAIN_TAB_UNSUPPORTED_LEGACY_DEGENERATE = 3' in p
assert 'n == 1 .and. .not. (parameters%groundwater_depth(1) > 0.0_real64)' in p
assert 'diagnostics%status = DRAIN_TAB_UNSUPPORTED_LEGACY_DEGENERATE' in p
for forbidden in ['HeadCalc','headcalc','AFGEN','qdrtab','open(','read(','write(unit','t1900','dramet']:
    assert forbidden not in p, forbidden
assert 'SAVE' not in p.upper()
assert 'persistent_process_state = .false.' in p
assert 'mass_is_authoritative_external_transfer = .true.' in p
print('FPM08C1R_DEGENERATE_REJECTION_STATIC=PASS')
print('FPM08C1R_NO_LEGACY_STORAGE_OR_IO_LEAKAGE=PASS')
print('FPM08C1R_STATELESS_MASS_BOUNDARY_STATIC=PASS')
PY

# Full original C1 regression gate must remain green.
bash tests/fpm/run_fpm08c1_tabulated_drainage_response_gate.sh > "$BUILD/original.txt" 2>&1 || {
  cat "$BUILD/original.txt" >&2
  exit 1
}
grep -Fq 'FPM08C1_TABULATED_DRAINAGE_RESPONSE_GATE PASS' "$BUILD/original.txt"
echo 'FPM08C1R_ORIGINAL_C1_REGRESSION=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/mod_soil_water_solver_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_process_hydraulic_view.f90 -o "$OUT/mod_process_hydraulic_view.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_drainage_tabulated_response.f90 -o "$OUT/mod_drainage_tabulated_response.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_fpm08c1r_tabulated_drainage_remediation.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/mod_soil_water_solver_contract.o" "$OUT/mod_process_hydraulic_view.o" \
    "$OUT/mod_drainage_tabulated_response.o" "$OUT/test.o" -o "$OUT/test_fpm08c1r"
  "$OUT/test_fpm08c1r" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  for marker in \
    'FPM08C1R_ZERO_DEPTH_SINGLETON_FAIL_CLOSED=PASS' \
    'FPM08C1R_POSITIVE_DEPTH_SINGLETON_CONSTANT=PASS' \
    'FPM08C1R_MULTI_POINT_ZERO_START_UNCHANGED=PASS' \
    'FPM08C1R_STATE_AND_MASS_BOUNDARY_UNCHANGED=PASS' \
    'FPM08C1R_TABULATED_DRAINAGE_REMEDIATION_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FPM08C1R_FOCUSED_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM08C1R_FOCUSED_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FPM08C1R_FOCUSED_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FPM08C1R_TABULATED_DRAINAGE_REMEDIATION_GATE PASS'
