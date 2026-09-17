#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fapp04-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=327689a4e169a03d8bd8b27b45df98794fb81cde
expected_src=$'src/runtime/mod_fmr_pmdirect_ptra_root_input_binding.f90\nsrc/runtime/mod_fmr_pmdirect_surface_evaporation_binding.f90'
changed_src="$(git diff --name-only "$BASE" -- src | sort)"
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'FAPP04_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FAPP04_PRODUCTION_DELTA_TWO_TRANSPARENT_BINDINGS=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FAPP04_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/process/mod_pmdirect_swetr0_process.f90 fcf35da81011543bac7cf0c71bcbd7ac34b09b64
check_blob src/process/mod_reference_et_demand_process.f90 f5e88ec5089fd3b57ac111065fab2aa32dde0fae
check_blob src/runtime/mod_fmr_reference_et_demand_binding.f90 8c679f911c9a82c498258224d83f5fce3cb09163
check_blob src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90 11ef6182414af4fbe67eebec3d6f14742df04aca
check_blob src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90 b8ff1fb1d9434e952163b6955305c6373dd8ac82
echo 'FAPP04_FAPP03_AND_SWETR1_PROTECTED_BLOBS=PASS'

python3 - <<'PY'
from pathlib import Path
paths = [
    Path('src/runtime/mod_fmr_pmdirect_ptra_root_input_binding.f90'),
    Path('src/runtime/mod_fmr_pmdirect_surface_evaporation_binding.f90'),
]
text = '\n'.join(p.read_text() for p in paths)
low = text.lower()
for forbidden in [
    'mod_kernel_transactions', 'soil_water_solver', 'mod_canonical_contracts',
    'mod_reference_et_demand_process', 'mod_fmr_reference_et_demand_binding',
    'mod_fmr_surface_evaporation_runtime_materialization',
    'open(', 'read(', 'headcalc', 'newton', 'jacobian'
]:
    assert forbidden not in low, forbidden
assert 'pmdirect_result%potential_transpiration_cm_per_day' in text
assert 'pmdirect_result%potential_soil_evaporation_cm_per_day' in text
assert 'pmdirect_result%potential_pond_evaporation_cm_per_day' in text
assert 'bound_input%potential_transpiration = ptra' in text
assert 'demand%bare_soil_demand = bare_demand' in text
assert 'demand%ponded_water_demand = ponded_demand' in text
print('FAPP04_NO_PARALLEL_RUNTIME_OR_SOLVER_COUPLING=PASS')
print('FAPP04_DIRECT_POSTIMAGE_MAPPING_STATIC=PASS')
PY

COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/process/mod_pmdirect_swetr0_process.f90 -o "$OUT/mod_pmdirect_swetr0_process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/crop/mod_crop_root_uptake_input_contract.f90 -o "$OUT/mod_crop_root_uptake_input_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/process/mod_restricted_surface_evaporation.f90 -o "$OUT/mod_restricted_surface_evaporation.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_pmdirect_ptra_root_input_binding.f90 -o "$OUT/mod_fmr_pmdirect_ptra_root_input_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_pmdirect_surface_evaporation_binding.f90 -o "$OUT/mod_fmr_pmdirect_surface_evaporation_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fapp/test_fapp04_pmdirect_typed_bindings.f90 -o "$OUT/test_fapp04_pmdirect_typed_bindings.o"

  gfortran -O"$opt" \
    "$OUT/mod_pmdirect_swetr0_process.o" \
    "$OUT/mod_crop_root_uptake_input_contract.o" \
    "$OUT/mod_restricted_surface_evaporation.o" \
    "$OUT/mod_fmr_pmdirect_ptra_root_input_binding.o" \
    "$OUT/mod_fmr_pmdirect_surface_evaporation_binding.o" \
    "$OUT/test_fapp04_pmdirect_typed_bindings.o" \
    -o "$OUT/test_fapp04_pmdirect_typed_bindings"

  "$OUT/test_fapp04_pmdirect_typed_bindings" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    exit 1
  }

  for marker in \
    'FAPP04_PMDIRECT_ROOT_EXACT_MAPPING=PASS' \
    'FAPP04_PMDIRECT_INACTIVE_CROP_CANONICAL_ZERO=PASS' \
    'FAPP04_PMDIRECT_ROOT_NONFINITE_FAIL_CLOSED=PASS' \
    'FAPP04_PMDIRECT_ROOT_GEOMETRY_FAIL_CLOSED=PASS' \
    'FAPP04_PMDIRECT_ROOT_UPSTREAM_FAIL_CLOSED=PASS' \
    'FAPP04_PMDIRECT_SURFACE_EXACT_MAPPING=PASS' \
    'FAPP04_PMDIRECT_SURFACE_NONFINITE_FAIL_CLOSED=PASS' \
    'FAPP04_PMDIRECT_SURFACE_UPSTREAM_FAIL_CLOSED=PASS' \
    'F-APP04 PMdirect typed bindings PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FAPP04_TYPED_BINDINGS_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FAPP04_TYPED_BINDINGS_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FAPP04_TYPED_BINDINGS_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FAPP04_PMDIRECT_TYPED_BINDINGS_GATE PASS'
