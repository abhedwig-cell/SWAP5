#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl12-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PYTHONPATH=research/ahl python3 research/ahl/ahl12_generate_variants.py "$BUILD/tables" | tee "$BUILD/table_summary.txt"

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
  research/ahl/mod_ahl09_dc_provider.f90
)
OUT="$BUILD/o2"; mkdir -p "$OUT"; objects=()
for source in "${SRC[@]}"; do
  obj="$OUT/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c research/ahl/test_ahl10_matrix.f90 -o "$OUT/test.o"
gfortran -O2 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

RESULT="${1:-/tmp/ahl12_result.txt}"
: > "$RESULT"
for variant in theta1 k1 both1; do
  while read -r material regime h0 hbot; do
    set +e
    "$OUT/test" "$BUILD/tables/${material}_${variant}_dc.dat" "$material" "$regime" "$h0" "$hbot" 2>&1 | tee -a "$RESULT"
    rc=${PIPESTATUS[0]}
    set -e
    if [[ "$rc" -eq 0 ]]; then verdict=PASS; else verdict=FAIL; fi
    echo "AHL12_CASE_STATUS ${variant} ${material}:${regime} ${verdict}" | tee -a "$RESULT"
  done <<'CASES'
B01 wet -10 -7.5
B01 dry -500 -400
B12 wet -10 -7.5
B12 dry -500 -400
O05 wet -10 -7.5
O14 dry -500 -400
CASES
done
echo "AHL12_ATTRIBUTION_MATRIX=COMPLETE" | tee -a "$RESULT"
