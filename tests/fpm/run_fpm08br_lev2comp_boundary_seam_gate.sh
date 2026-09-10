#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm08br-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=186df3daa27d7b3541da694190d6f8ec9fab7da6
EXPECTED_SOURCE_BLOB=1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a

changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "src/process/mod_drainage_spatial_distribution.f90" ]] || {
  echo 'FPM08BR_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FPM08BR_SINGLE_PRODUCTION_FILE_DELTA=PASS'

for protected in src/runtime src/solver src/kernel reference; do
  changed="$(git diff --name-only "$BASE" -- "$protected")"
  [[ -z "$changed" ]] || {
    echo "FPM08BR_PROTECTED_DELTA $protected" >&2
    printf '%s\n' "$changed" >&2
    exit 1
  }
done
echo 'FPM08BR_NO_RUNTIME_SOLVER_KERNEL_REFERENCE_DELTA=PASS'

actual_source_blob="$(git hash-object src/process/mod_drainage_spatial_distribution.f90)"
[[ "$actual_source_blob" == "$EXPECTED_SOURCE_BLOB" ]] || {
  echo "FPM08BR_SOURCE_BLOB_MISMATCH expected=$EXPECTED_SOURCE_BLOB actual=$actual_source_blob" >&2
  exit 1
}
echo 'FPM08BR_REMEDIATED_SOURCE_BLOB=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('src/process/mod_drainage_spatial_distribution.f90').read_text()
assert 'LEGACY_LEVEL_TO_COMPARTMENT_OFFSET = 1.0e-10_real64' in p
assert 'wlev > -parameters%zbotcp(wt_node) + LEGACY_LEVEL_TO_COMPARTMENT_OFFSET' in p
assert 'wlev >= -parameters%zbotcp(n)' in p
assert 'wt_node == n .and. dz_top_sat <= 0.0_real64' in p
assert 'wt_node < n .and. dz_top_sat < -LEGACY_LEVEL_TO_COMPARTMENT_OFFSET' not in p
assert 'scalar_transfer - sum_previous' in p
assert 'LEGACY_ACTIVE_MAGNITUDE = 1.0e-10_real64' in p
for forbidden in ['HeadCalc', 'headcalc', 'MOD_drainage', 'DIVDRA(', 'open(', 'read(', 'write(unit', 'drainage_resistance', 'drain_head']:
    assert forbidden not in p, forbidden
assert 'SAVE' not in p.upper()
assert 'pressure_head' not in p
assert 'water_content' not in p
print('FPM08BR_EXPLICIT_FROZEN_LEV2COMP_SEAM_STATIC=PASS')
print('FPM08BR_NO_NONLEGACY_INTERNAL_SEAM_GUARD=PASS')
print('FPM08BR_PROFILE_BOTTOM_HOLD_STATIC=PASS')
print('FPM08BR_MASS_CLOSURE_PATH_UNCHANGED_STATIC=PASS')
print('FPM08BR_NO_SCOPE_BROADENING_STATIC=PASS')
PY

# The complete original F-PM08B structural candidate gate must remain green.
bash tests/fpm/run_fpm08b_drainage_spatial_distribution_gate.sh > "$BUILD/fpm08b-regression.txt" 2>&1 || {
  cat "$BUILD/fpm08b-regression.txt" >&2
  exit 1
}
grep -Fq 'FPM08B_DRAINAGE_SPATIAL_DISTRIBUTION_GATE PASS' "$BUILD/fpm08b-regression.txt"
echo 'FPM08BR_PARENT_FPM08B_REGRESSION_GATE=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/mod_soil_water_solver_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_process_hydraulic_view.f90 -o "$OUT/mod_process_hydraulic_view.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_drainage_spatial_distribution.f90 -o "$OUT/mod_drainage_spatial_distribution.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_fpm08br_lev2comp_boundary_seam.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/mod_soil_water_solver_contract.o" "$OUT/mod_process_hydraulic_view.o" \
    "$OUT/mod_drainage_spatial_distribution.o" "$OUT/test.o" -o "$OUT/test_fpm08br"
  "$OUT/test_fpm08br" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for marker in \
    'FPM08BR_EXACT_INTERNAL_BOUNDARY_SHALLOWER_COMPARTMENT=PASS' \
    'FPM08BR_HALF_SEAM_BELOW_BOUNDARY_SHALLOWER_COMPARTMENT=PASS' \
    'FPM08BR_FULL_SEAM_BELOW_BOUNDARY_SHALLOWER_COMPARTMENT=PASS' \
    'FPM08BR_BEYOND_SEAM_NEXT_COMPARTMENT=PASS' \
    'FPM08BR_GENERIC_INTERNAL_BOUNDARY_SEAM=PASS' \
    'FPM08BR_PROFILE_BOTTOM_REMAINS_FAIL_CLOSED=PASS' \
    'FPM08BR_EXACT_SCALAR_TO_NODE_MASS_IDENTITY=PASS' \
    'FPM08BR_LEV2COMP_BOUNDARY_SEAM_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FPM08BR_REMEDIATION_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM08BR_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FPM08BR_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FPM08BR_LEV2COMP_BOUNDARY_SEAM_GATE PASS'
