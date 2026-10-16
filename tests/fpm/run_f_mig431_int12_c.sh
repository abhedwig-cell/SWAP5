#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-int12-c-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=a86da5b6931b15ef8a5432fd03adc30a72491b65
expected_src=$'src/runtime/mod_fmr_interception_source_window_binding.f90\nsrc/runtime/mod_fmr_production_application_bootstrap.f90'
changed_src="$(git diff --name-only "$BASE" -- src | sort)"
if [[ -f tests/fpm/hyd_default_projection.json ]]; then
  # The exact HYD owner proof must accept the entire scientific delta first.
  # Remove only its three declared files before the unchanged INT12-C check.
  python3 -B tests/fpm/verify_hyd_successor.py --source-only
  changed_src="$(printf '%s\n' "$changed_src" | python3 -c "import sys; allowed={'src/solver/mod_b110_default_mvg_provider.f90','src/solver/mod_reference_richards_temporal_indicator.f90','src/runtime/mod_fmr_serialized_reference_backend.f90'}; print('\n'.join(p for p in sys.stdin.read().splitlines() if p not in allowed))")"
fi
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'INT12C_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
python3 tests/fpm/check_int12c_current_composition.py

COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/process/mod_pmdirect_swetr0_process.f90 -o "$OUT/pmdirect.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/runtime/mod_interception_source_window_runtime.f90 -o "$OUT/int12_p0.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -Wno-error=unused-dummy-argument -O"$opt" -J"$OUT" -I"$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/soil_water_solver_contract.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J"$OUT" -I"$OUT" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$OUT/b110_default_mvg.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/process/mod_restricted_surface_evaporation.f90 -o "$OUT/restricted_surface_evaporation.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J"$OUT" -I"$OUT" -c src/solver/mod_b110_dynamic_top_boundary_provider.f90 -o "$OUT/b110_dynamic_top.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/runtime/mod_fmr_pmdirect_dynamic_top_boundary_binding.f90 -o "$OUT/pmdirect_top_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/runtime/mod_fmr_interception_source_window_binding.f90 -o "$OUT/int12_c_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c tests/fpm/test_f_mig431_int12_c.f90 -o "$OUT/int12_c_test.o"
  gfortran -O"$opt" "$OUT/pmdirect.o" "$OUT/int12_p0.o" "$OUT/soil_water_solver_contract.o" \
    "$OUT/b110_default_mvg.o" "$OUT/b110_dynamic_top.o" "$OUT/pmdirect_top_binding.o" \
    "$OUT/restricted_surface_evaporation.o" "$OUT/int12_c_binding.o" "$OUT/int12_c_test.o" -o "$OUT/int12-c"
  "$OUT/int12-c" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  grep -Fq 'F-MIG431-INT12-C RESTRICTED HUPSEL COMPOSITION PASS' "$OUT/output.txt"
  # Preserve the original scientific driver, and execute unchanged F-APP03/04
  # production-binding drivers with the same per-optimization providers.
  for source in src/crop/mod_crop_root_uptake_input_contract.f90 \
      src/runtime/mod_fmr_pmdirect_ptra_root_input_binding.f90 \
      src/runtime/mod_fmr_pmdirect_surface_evaporation_binding.f90; do
    name="$(basename "$source" .f90)"
    gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$source" -o "$OUT/$name.o"
  done
  provider_objects=("$OUT/pmdirect.o" "$OUT/int12_p0.o" "$OUT/soil_water_solver_contract.o"
    "$OUT/b110_default_mvg.o" "$OUT/b110_dynamic_top.o" "$OUT/pmdirect_top_binding.o"
    "$OUT/restricted_surface_evaporation.o" "$OUT/int12_c_binding.o"
    "$OUT/mod_crop_root_uptake_input_contract.o" "$OUT/mod_fmr_pmdirect_ptra_root_input_binding.o"
    "$OUT/mod_fmr_pmdirect_surface_evaporation_binding.o")
  for driver in tests/fapp/test_fapp03_pmdirect_swetr0_process.f90 \
      tests/fapp/test_fapp04_pmdirect_typed_bindings.f90 \
      tests/fapp/test_fapp04_pmdirect_dynamic_top_binding.f90 \
      tests/fpm/test_f_mig431_int12_p0.f90; do
    name="$(basename "$driver" .f90)"
    gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$driver" -o "$OUT/$name.o"
    gfortran -O"$opt" "${provider_objects[@]}" "$OUT/$name.o" -o "$OUT/$name"
    "$OUT/$name" > "$OUT/$name.txt" 2>&1 || { cat "$OUT/$name.txt" >&2; exit 1; }
    cat "$OUT/$name.txt"
  done
  echo "INT12C_O$opt=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
for name in test_fapp03_pmdirect_swetr0_process test_fapp04_pmdirect_typed_bindings \
    test_fapp04_pmdirect_dynamic_top_binding test_f_mig431_int12_p0; do
  cmp "$BUILD/o0/$name.txt" "$BUILD/o2/$name.txt"
done
echo 'INT12C_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "INT12C_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'F-MIG431-INT12-C QUALIFICATION PASS'
