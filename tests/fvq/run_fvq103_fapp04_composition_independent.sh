#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq103-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

SUBJECT=f3c056bf236c21fd477a2ee570c4755d5249d5f3

changed_src="$(git diff --name-only "$SUBJECT" -- src)"
[[ -z "$changed_src" ]] || {
  echo 'FVQ103_PRODUCTION_MUTATION_DETECTED' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FVQ103_NO_PRODUCTION_MUTATION=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FVQ103_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/runtime/mod_fmr_pmdirect_ptra_root_input_binding.f90 89d2d42e85c51d0b174d0382dabd3ec8f7417b68
check_blob src/runtime/mod_fmr_pmdirect_surface_evaporation_binding.f90 1a67d8a25727c2e821dd11e4853aa925e43cd95b
check_blob src/runtime/mod_fmr_pmdirect_dynamic_top_boundary_binding.f90 a6e1ed43bb9ee7cb13d088668c3874a11877980a
check_blob src/process/mod_pmdirect_swetr0_process.f90 fcf35da81011543bac7cf0c71bcbd7ac34b09b64
check_blob src/process/mod_reference_et_demand_process.f90 f5e88ec5089fd3b57ac111065fab2aa32dde0fae
check_blob src/runtime/mod_fmr_reference_et_demand_binding.f90 8c679f911c9a82c498258224d83f5fce3cb09163
check_blob src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90 11ef6182414af4fbe67eebec3d6f14742df04aca
check_blob src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90 b8ff1fb1d9434e952163b6955305c6373dd8ac82
check_blob src/solver/mod_b110_dynamic_top_boundary_provider.f90 3eadae0f32aba49534cd58464e28c0af5bc9bf7d
check_blob src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90 7a3cc3d01d994ea21bb0b48798cd2fb4aba9495e
echo 'FVQ103_SUBJECT_AND_PROTECTED_BLOBS=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('tests/fvq/test_fvq103_fapp04_composition_independent.f90')
text = p.read_text().lower()
for forbidden in [
    'evaluate_pmdirect_swetr0_daily',
    'apply_swinter1_daily_interval',
    'daily_atmospheric_transmission',
    'aerodynamic_resistance',
    'angstrom',
    'penman',
    'lambda =',
    'gamma =',
    'rnl ='
]:
    assert forbidden not in text, forbidden
for required in [
    'fmr_bind_pmdirect_ptra_to_root_input',
    'fmr_bind_pmdirect_surface_evaporation_demand',
    'fmr_bind_pmdirect_net_rain_to_dynamic_top_request',
    'same_bits'
]:
    assert required in text, required
print('FVQ103_NO_PMDIRECT_FORMULA_REIMPLEMENTATION=PASS')
print('FVQ103_INDEPENDENT_BINDING_SURFACE=PASS')
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
    tests/fvq/test_fvq103_fapp04_composition_independent.f90 -o "$OUT/test_fvq103.o"

  gfortran -O"$opt" \
    "$OUT/mod_pmdirect_swetr0_process.o" \
    "$OUT/mod_crop_root_uptake_input_contract.o" \
    "$OUT/mod_restricted_surface_evaporation.o" \
    "$OUT/mod_soil_water_solver_contract.o" \
    "$OUT/mod_b110_default_mvg_provider.o" \
    "$OUT/mod_b110_dynamic_top_boundary_provider.o" \
    "$OUT/mod_fmr_pmdirect_ptra_root_input_binding.o" \
    "$OUT/mod_fmr_pmdirect_surface_evaporation_binding.o" \
    "$OUT/mod_fmr_pmdirect_dynamic_top_boundary_binding.o" \
    "$OUT/test_fvq103.o" \
    -o "$OUT/test_fvq103"

  "$OUT/test_fvq103" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    exit 1
  }

  for marker in \
    'FVQ103_ROOT_IDENTITY_SWEEP=PASS n=8' \
    'FVQ103_ROOT_INACTIVE_CANONICAL_ZERO=PASS' \
    'FVQ103_SURFACE_IDENTITY_SWEEP=PASS n=6' \
    'FVQ103_DYNAMIC_TOP_IDENTITY_PRESERVATION_SWEEP=PASS n=8' \
    'FVQ103_ROOT_FAIL_CLOSED=PASS' \
    'FVQ103_SURFACE_FAIL_CLOSED=PASS' \
    'FVQ103_DYNAMIC_TOP_FAIL_CLOSED=PASS' \
    'F-VQ103 F-APP04 independent composition PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FVQ103_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FVQ103_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FVQ103_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'F-VQ103 PASS'
