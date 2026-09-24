#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl04b-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 research/ahl/ahl04b_generate_attribution_tables.py "$BUILD/tables" | tee "$BUILD/table_summary.json"

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
  research/ahl/mod_ahl04_hybrid_lookup_provider.f90
)
OUT="$BUILD/o2"
mkdir -p "$OUT"
objects=()
for source in "${SRC[@]}"; do
  obj="$OUT/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c research/ahl/test_ahl04a_richards_provider_replay.f90 -o "$OUT/test.o"
gfortran -O2 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

RESULT="${1:-/tmp/ahl04b_result.txt}"
: > "$RESULT"
for v in base theta3 theta1 c3 c1 k3 k1; do
  "$OUT/test" "$BUILD/tables/${v}.dat" "$v" | tee -a "$RESULT"
done
echo "AHL04B_ATTRIBUTION_SWEEP=COMPLETE" | tee -a "$RESULT"
