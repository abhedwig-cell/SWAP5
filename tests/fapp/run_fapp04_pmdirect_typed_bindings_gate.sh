#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fapp04-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=327689a4e169a03d8bd8b27b45df98794fb81cde
expected_src=$'src/runtime/mod_fmr_pmdirect_dynamic_top_boundary_binding.f90\nsrc/runtime/mod_fmr_pmdirect_ptra_root_input_binding.f90\nsrc/runtime/mod_fmr_pmdirect_surface_evaporation_binding.f90'
changed_src="$(git diff --name-only "$BASE" -- src | sort)"
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'FAPP04_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FAPP04_PRODUCTION_DELTA_THREE_TRANSPARENT_BINDINGS=PASS'

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

check_blob src/solver/mod_b110_dynamic_top_boundary_provider.f90 3eadae0f32aba49534cd58464e28c0af5bc9bf7d
check_blob src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90 7a3cc3d01d994ea21bb0b48798cd2fb4aba9495e
echo 'FAPP04_DYNAMIC_TOP_OWNER_BLOBS=PASS'

python3 - <<'PY'
from pathlib import Path
paths = [
    Path('src/runtime/mod_fmr_pmdirect_dynamic_top_boundary_binding.f90'),
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
assert 'pmdirect_result%net_rain_cm_per_day' in text
assert 'bound_input%potential_transpiration = ptra' in text
assert 'demand%bare_soil_demand = bare_demand' in text
assert 'demand%ponded_water_demand = ponded_demand' in text
assert 'bound_request%precipitation_rate_cm_per_day = net_rain' in text
assert 'mod_b110_dynamic_top_boundary_provider' in low
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
  gfortran "${COMMON[@]}" -Wno-error=unused-dummy-argument -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/mod_soil_water_solver_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/solver/mod_b110_default_mvg_provider.f90 -o "$OUT/mod_b110_default_mvg_provider.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/solver/mod_b110_dynamic_top_boundary_provider.f90 -o "$OUT/mod_b110_dynamic_top_boundary_provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_pmdirect_ptra_root_input_binding.f90 -o "$OUT/mod_fmr_pmdirect_ptra_root_input_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_pmdirect_surface_evaporation_binding.f90 -o "$OUT/mod_fmr_pmdirect_surface_evaporation_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_pmdirect_dynamic_top_boundary_binding.f90 -o "$OUT/mod_fmr_pmdirect_dynamic_top_boundary_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fapp/test_fapp04_pmdirect_typed_bindings.f90 -o "$OUT/test_fapp04_pmdirect_typed_bindings.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fapp/test_fapp04_pmdirect_dynamic_top_binding.f90 -o "$OUT/test_fapp04_pmdirect_dynamic_top_binding.o"

  gfortran -O"$opt" \
    "$OUT/mod_pmdirect_swetr0_process.o" \
    "$OUT/mod_crop_root_uptake_input_contract.o" \
    "$OUT/mod_restricted_surface_evaporation.o" \
    "$OUT/mod_fmr_pmdirect_ptra_root_input_binding.o" \
    "$OUT/mod_fmr_pmdirect_surface_evaporation_binding.o" \
    "$OUT/test_fapp04_pmdirect_typed_bindings.o" \
    -o "$OUT/test_fapp04_pmdirect_typed_bindings"

  gfortran -O"$opt" \
    "$OUT/mod_pmdirect_swetr0_process.o" \
    "$OUT/mod_soil_water_solver_contract.o" \
    "$OUT/mod_b110_default_mvg_provider.o" \
    "$OUT/mod_restricted_surface_evaporation.o" \
    "$OUT/mod_b110_dynamic_top_boundary_provider.o" \
    "$OUT/mod_fmr_pmdirect_dynamic_top_boundary_binding.o" \
    "$OUT/test_fapp04_pmdirect_dynamic_top_binding.o" \
    -o "$OUT/test_fapp04_pmdirect_dynamic_top_binding"

  "$OUT/test_fapp04_pmdirect_typed_bindings" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    exit 1
  }
  "$OUT/test_fapp04_pmdirect_dynamic_top_binding" >> "$OUT/output.txt" 2>&1 || {
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
    'F-APP04 PMdirect typed bindings PASS' \
    'FAPP04_PMDIRECT_NET_RAIN_EXACT_MAPPING=PASS' \
    'FAPP04_PMDIRECT_DYNAMIC_TOP_NONPRECIP_FIELDS_PRESERVED=PASS' \
    'FAPP04_PMDIRECT_INCOMING_PRECIP_IGNORED=PASS' \
    'FAPP04_PMDIRECT_ZERO_NET_RAIN_MAPPING=PASS' \
    'FAPP04_PMDIRECT_NET_RAIN_NONFINITE_FAIL_CLOSED=PASS' \
    'FAPP04_PMDIRECT_NET_RAIN_NEGATIVE_FAIL_CLOSED=PASS' \
    'FAPP04_PMDIRECT_NET_RAIN_UPSTREAM_FAIL_CLOSED=PASS' \
    'F-APP04 PMdirect dynamic-top binding PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FAPP04_TYPED_COMPOSITION_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FAPP04_TYPED_COMPOSITION_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FAPP04_TYPED_COMPOSITION_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FAPP04_PMDIRECT_TYPED_COMPOSITION_GATE PASS'
