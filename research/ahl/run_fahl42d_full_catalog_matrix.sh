#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl42d-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/params"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
python3 research/ahl/fahl42d_materialize_catalog_params.py "$BUILD/params"

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
OUT="$BUILD/o2"; mkdir -p "$OUT"; objects=()
for source in "${SRC[@]}"; do
  obj="$OUT/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c research/ahl/test_fahl42d_full_catalog_matrix.f90 -o "$OUT/test.o"
gfortran -O2 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

RESULT="${1:-/tmp/fahl42d_result.txt}"; : > "$RESULT"
fail=0; pass=0
for prefix in B O; do
  for i in $(seq -w 1 18); do
    m="${prefix}${i}"
    for spec in "wet -10 -7.5" "mid -75 -50" "dry -500 -400"; do
      read -r regime h0 hbot <<< "$spec"
      set +e
      "$OUT/test" "$BUILD/params/${m}.dat" "$m" "$regime" "$h0" "$hbot" 2>&1 | tee -a "$RESULT"
      rc=${PIPESTATUS[0]}
      set -e
      if [[ "$rc" -eq 0 ]]; then pass=$((pass+1)); else fail=$((fail+1)); fi
      echo "FAHL42D_CASE_STATUS ${m}:${regime} rc=${rc}" | tee -a "$RESULT"
    done
  done
done
echo "FAHL42D_COUNTS PASS=${pass} FAIL=${fail}" | tee -a "$RESULT"
[[ "$pass" -eq 108 && "$fail" -eq 0 ]]
echo "FAHL42D_MATRIX_108_OF_108=PASS" | tee -a "$RESULT"
