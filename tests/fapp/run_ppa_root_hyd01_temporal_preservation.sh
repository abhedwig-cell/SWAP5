#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-root-hyd01-preserve-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PPA_ROOT_HYD01_PRESERVE_FAIL $*" >&2; exit 62; }

BASE=1dc12a3f47935a3639ef3fb38dc0d6338a0f44c0
git merge-base --is-ancestor "$BASE" HEAD || fail "branch is not descended from frozen authority base"
changed_src="$(git diff --name-only "$BASE"..HEAD -- src | sort)"
expected_src='src/solver/mod_reference_richards_temporal_indicator.f90'
[[ "$changed_src" == "$expected_src" ]] || { printf '%s\n' "$changed_src" >&2; fail "unexpected production source delta"; }
git diff --quiet "$BASE"..HEAD -- reference || fail "reference source changed"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/process/mod_snow_process.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_fmr_groundwater_swap_participant.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
)


run_opt(){
  local opt="$1"
  local out="$BUILD/o$opt"
  mkdir -p "$out"
  local objects=()
  local source obj
  for source in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj" || fail "compile $source O$opt"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi38_prescribed_qbot_temporal_certificate.f90 -o "$out/fsi38.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/fsi38.o" -o "$out/fsi38"
  "$out/fsi38" > "$out/fsi38.txt" 2>&1 || { cat "$out/fsi38.txt" >&2; fail "FSI38 O$opt"; }

  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi25_reference_indicator_production_seam.f90 -o "$out/fsi25.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/fsi25.o" -o "$out/fsi25"
  "$out/fsi25" -75.0 0.01 > "$out/fsi25.txt" 2>&1 || { cat "$out/fsi25.txt" >&2; fail "FSI25 O$opt"; }


}

run_opt 0
run_opt 2

for marker in   'FSI38_PRESCRIBED_QBOT_TEMPORAL_CERTIFICATE=PASS'; do
  grep -Fq "$marker" "$BUILD/o0/fsi38.txt" || { cat "$BUILD/o0/fsi38.txt" >&2; fail "missing $marker"; }
done
grep -Fq 'FSI25_REFERENCE_INDICATOR_CASE PASS' "$BUILD/o0/fsi25.txt" || { cat "$BUILD/o0/fsi25.txt" >&2; fail "FSI25 marker"; }
grep -Fq ':EXTRA_NONLINEAR=0:EXTRA_TRIDAG=1:' "$BUILD/o0/fsi25.txt" || { cat "$BUILD/o0/fsi25.txt" >&2; fail "FSI25 bounded cost"; }
for marker in   'FMR44R_MODE2_EQUILIBRIUM_TRANSACTION=PASS'   'FMR44R_POSITIVE_QBOT_ACCEPTED_INFLOW=PASS'   'FMR44R_NEARBY_BOTTOM_MODE_FAIL_CLOSED=PASS'   'FMR44R_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE=PASS'; do
  grep -Fq "$marker" "$BUILD/o0/fmr44r.txt" || { cat "$BUILD/o0/fmr44r.txt" >&2; fail "missing $marker"; }
done

for name in fsi38 fsi25; do
  diff -u "$BUILD/o0/$name.txt" "$BUILD/o2/$name.txt" || fail "$name O0/O2 output identity"
done

cat "$BUILD/o0/fsi38.txt"
cat "$BUILD/o0/fsi25.txt"
echo 'PPA_ROOT_HYD01_PRESERVE_FSI38=PASS'
echo 'PPA_ROOT_HYD01_PRESERVE_FSI25=PASS'
echo 'PPA_ROOT_HYD01_PRESERVATION_GATE=PASS'
