#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; BUILD="${RUNNER_TEMP:-/tmp}/ahl25e-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables" "$BUILD/o2"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
PYTHONPATH=research/ahl python3 research/ahl/ahl25d_generate_tables.py "$BUILD/tables" >/dev/null
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(tests/fsi/fsi04_real_headcalc_stubs.f90 src/solver/mod_soil_water_accepted_step_direction_contract.f90 src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 src/runtime/mod_a23bu_worker_execution_context.f90 src/solver/mod_soil_water_solver_contract.f90 src/solver/mod_reference_richards_workspace.f90 src/solver/mod_reference_richards_state_binding.f90 src/solver/mod_reference_linear_solver.f90 src/solver/mod_b110_default_mvg_provider.f90 src/solver/mod_b110_source_sink_provider.f90 src/solver/mod_b110_root_sink_provider.f90 src/solver/mod_fixed_flux_top_boundary_provider.f90 src/solver/mod_reference_richards_temporal_indicator.f90 tests/fmr/mod_fmr04_fixed_top_provider.f90 src/legacy/b1_10_port/headcalc.f90 src/adapter/mod_reference_richards_legacy_binding.f90 research/ahl/mod_ahl25d_model3_analytical.f90 research/ahl/mod_ahl25d_model3_lookup.f90)
objects=();for source in "${SRC[@]}";do obj="$BUILD/o2/$(basename "${source%.*}").o";gfortran "${COMMON[@]}" -O2 -J "$BUILD/o2" -I "$BUILD/o2" -c "$source" -o "$obj";objects+=("$obj");done
gfortran "${COMMON[@]}" -O2 -J "$BUILD/o2" -I "$BUILD/o2" -c research/ahl/test_ahl25e_attribution.f90 -o "$BUILD/o2/test.o";gfortran -O2 "${objects[@]}" "$BUILD/o2/test.o" -o "$BUILD/o2/test"
RESULT="${1:-/tmp/ahl25e.txt}";:>"$RESULT"
for spec in "M3_SEPARATED wet -10 -7.5" "M3_DOMINANT_SECOND dry -500 -400";do read -r m r h hb <<< "$spec";for mode in selected exact_k exact_ret;do "$BUILD/o2/test" "$BUILD/tables/$m.dat" "$m" "$r" "$h" "$hb" "$mode"|tee -a "$RESULT";done;done
