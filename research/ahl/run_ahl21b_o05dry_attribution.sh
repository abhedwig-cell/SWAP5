#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/ahl21b-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
PYTHONPATH=research/ahl python3 research/ahl/ahl11_generate_decoupled_support.py "$BUILD/tables" >/tmp/ahl21b_tables.txt
C=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(tests/fsi/fsi04_real_headcalc_stubs.f90 src/solver/mod_soil_water_accepted_step_direction_contract.f90 src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 src/runtime/mod_a23bu_worker_execution_context.f90 src/solver/mod_soil_water_solver_contract.f90 src/solver/mod_reference_richards_workspace.f90 src/solver/mod_reference_richards_state_binding.f90 src/solver/mod_reference_linear_solver.f90 src/solver/mod_b110_default_mvg_provider.f90 src/solver/mod_b110_source_sink_provider.f90 src/solver/mod_b110_root_sink_provider.f90 src/solver/mod_fixed_flux_top_boundary_provider.f90 src/solver/mod_reference_richards_temporal_indicator.f90 tests/fmr/mod_fmr04_fixed_top_provider.f90 src/legacy/b1_10_port/headcalc.f90 src/adapter/mod_reference_richards_legacy_binding.f90 research/ahl/mod_ahl11_decoupled_provider.f90 research/ahl/mod_ahl12b_exact_retention_klookup_provider.f90)
objs=()
for s in "${SRC[@]}"; do
  o="$BUILD/o2/$(basename "${s%.*}").o"
  gfortran "${C[@]}" -O2 -J "$BUILD/o2" -I "$BUILD/o2" -c "$s" -o "$o"
  objs+=("$o")
done
gfortran "${C[@]}" -O2 -J "$BUILD/o2" -I "$BUILD/o2" -c research/ahl/test_ahl21b_o05dry_attribution.f90 -o "$BUILD/o2/test.o"
gfortran -O2 "${objs[@]}" "$BUILD/o2/test.o" -o "$BUILD/test"
"$BUILD/test" "$BUILD/tables/O05_ret_dc.dat" "$BUILD/tables/O05_k03_k.dat" | tee /tmp/ahl21b_result.txt
