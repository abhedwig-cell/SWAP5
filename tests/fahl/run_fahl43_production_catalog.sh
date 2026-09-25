#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl43-catalog-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/params"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 tests/fahl/materialize_fahl43_catalog_parameters.py "$BUILD/params" | tee "$BUILD/catalog.txt"
grep -Fq 'FAHL43_CATALOG_PARAMETERS=36' "$BUILD/catalog.txt"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/solver/mod_b110_adaptive_hydraulic_builder.f90
  src/solver/mod_b110_adaptive_hydraulic_cache.f90
  src/solver/mod_b110_adaptive_hydraulic_provider.f90
)
objects=()
for source in "${SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done

gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c tests/fahl/test_fahl43_production_full_catalog.f90 -o "$BUILD/catalog_test.o"
gfortran -O2 "${objects[@]}" "$BUILD/catalog_test.o" -o "$BUILD/catalog_test"

RESULT="${1:-/tmp/fahl43_catalog.txt}"
: > "$RESULT"
count=0
for prefix in B O; do
  for i in $(seq -w 1 18); do
    m="${prefix}${i}"
    "$BUILD/catalog_test" "$BUILD/params/${m}.par" "$m" wet -10 -7.5 | tee -a "$RESULT"
    "$BUILD/catalog_test" "$BUILD/params/${m}.par" "$m" mid -75 -50 | tee -a "$RESULT"
    "$BUILD/catalog_test" "$BUILD/params/${m}.par" "$m" dry -500 -400 | tee -a "$RESULT"
    count=$((count+3))
  done
done
[[ "$count" -eq 108 ]]
grep -c '^FAHL43 .* PASS$' "$RESULT" | grep -qx '108'
echo 'FAHL43_PRODUCTION_MATRIX_108_OF_108=PASS' | tee -a "$RESULT"

gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c tests/fahl/test_fahl43_policy_identity.f90 -o "$BUILD/policy_test.o"
gfortran -O2 "${objects[@]}" "$BUILD/policy_test.o" -o "$BUILD/policy_test"
"$BUILD/policy_test" | tee -a "$RESULT"
grep -Fq 'FAHL43_POLICY_IDENTITY_3_VS_4=PASS' "$RESULT"

echo 'FAHL43_CATALOG_AND_POLICY=PASS' | tee -a "$RESULT"
