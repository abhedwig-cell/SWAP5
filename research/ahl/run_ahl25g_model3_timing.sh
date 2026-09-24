#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)";BUILD="${RUNNER_TEMP:-/tmp}/ahl25g-${GITHUB_RUN_ID:-local}-$$";mkdir -p "$BUILD/tables" "$BUILD/o3";trap 'rm -rf "$BUILD"' EXIT;cd "$ROOT"
PYTHONPATH=research/ahl python3 research/ahl/ahl25f_generate_tables.py "$BUILD/tables" 0.0001 >/dev/null
COMMON=(-std=f2008 -ffree-line-length-none)
SRC=(tests/fsi/fsi04_real_headcalc_stubs.f90 src/solver/mod_soil_water_accepted_step_direction_contract.f90 src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 src/runtime/mod_a23bu_worker_execution_context.f90 src/solver/mod_soil_water_solver_contract.f90 src/solver/mod_reference_richards_workspace.f90 src/solver/mod_reference_richards_state_binding.f90 src/solver/mod_reference_linear_solver.f90 src/solver/mod_b110_default_mvg_provider.f90 src/solver/mod_b110_source_sink_provider.f90 src/solver/mod_b110_root_sink_provider.f90 src/solver/mod_fixed_flux_top_boundary_provider.f90 src/solver/mod_reference_richards_temporal_indicator.f90 tests/fmr/mod_fmr04_fixed_top_provider.f90 src/legacy/b1_10_port/headcalc.f90 src/adapter/mod_reference_richards_legacy_binding.f90 research/ahl/mod_ahl25d_model3_analytical.f90 research/ahl/mod_ahl25d_model3_lookup.f90)
objects=();for source in "${SRC[@]}";do obj="$BUILD/o3/$(basename "${source%.*}").o";gfortran "${COMMON[@]}" -O3 -J "$BUILD/o3" -I "$BUILD/o3" -c "$source" -o "$obj";objects+=("$obj");done
gfortran "${COMMON[@]}" -O3 -J "$BUILD/o3" -I "$BUILD/o3" -c research/ahl/test_ahl25g_model3_timing.f90 -o "$BUILD/o3/test.o";gfortran -O3 "${objects[@]}" "$BUILD/o3/test.o" -o "$BUILD/o3/test"
RESULT="${1:-/tmp/ahl25g.txt}";:>"$RESULT"
for m in M3_BALANCED M3_SEPARATED M3_DOMINANT_SECOND;do for spec in "wet -10 -7.5" "mid -75 -50" "dry -500 -400";do read -r reg h hb <<< "$spec";"$BUILD/o3/test" "$BUILD/tables/$m.dat" "$m" "$reg" "$h" "$hb"|tee -a "$RESULT";done;done
