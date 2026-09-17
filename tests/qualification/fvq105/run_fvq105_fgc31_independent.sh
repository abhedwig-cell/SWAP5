#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq105-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FVQ105_QUALIFICATION_FAIL $*" >&2; exit 105; }

# Exact F-GC31 owner-qualified production postimage.
[[ "$(git rev-parse HEAD:src/solver/mod_b110_smooth_freatic_projection.f90)" == e83c1013a1d96508740619a71cfa1dbfdd665d61 ]] || fail 'smooth freatic projection drift'
[[ "$(git rev-parse HEAD:src/solver/mod_soil_water_accepted_step_direction_contract.f90)" == b5a0276d2f1b2c8ffe581e68dffecdaf55a32768 ]] || fail 'accepted-step direction contract drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_accepted_step_directional_service.f90)" == 8ca4e08f0297a6b7d0bca1608e9a1ac4d41f4fd7 ]] || fail 'accepted-step service drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_drainage_qbot_directional_binding.f90)" == 481dc8cb1af683053614de3a11c4155acb34b413 ]] || fail 'qbot drainage directional binding drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == 4e5491c997ed0752a4db9abd09b5ad3daf394db2 ]] || fail 'serialized backend drift'
[[ "$(git rev-parse HEAD:src/transaction/mod_accepted_trajectory_directional_sensitivity.f90)" == d267a763ceb697557e762c937a99b7f11cb44684 ]] || fail 'trajectory directional composition drift'
[[ "$(git rev-parse HEAD:src/transaction/mod_accepted_trajectory_directional_publication.f90)" == b1be9af9ece045cac1fd17087e6b08bc615bd733 ]] || fail 'trajectory publication drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90)" == 2d5342b45a61c9426d2b589b285050b648d141b9 ]] || fail 'predictor tangent adapter drift'

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
  src/solver/mod_b110_smooth_freatic_projection.f90
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
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
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
  src/solver/mod_b110_root_sink_provider.f90
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
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
)

run_one(){
  local opt="$1" tag="$2" out="$BUILD/$2"
  mkdir -p "$out"
  local objects=()
  for source in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$source" -o "$obj" || fail "compile $tag $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out"     -c tests/qualification/fvq105/test_fvq105_fgc31_independent.f90 -o "$out/test.o" || fail "compile oracle $tag"
  gfortran -fopenmp "$opt" "${objects[@]}" "$out/test.o" -o "$out/test" || fail "link $tag"
  timeout 180s "$out/test" > "$out/output.txt" 2>&1 || {
    cat "$out/output.txt" >&2
    fail "runtime $tag"
  }
  for marker in     'FVQ105_MULTI_SUBSTEP_ACTIVE_DRAINAGE=PASS'     'FVQ105_SAME_BACKEND_FD=PASS'     'FVQ105_PHYSICAL_IDENTITY=PASS'     'FVQ105_GWL_DIRECTION_CHAIN=PASS'     'FVQ105_DRAINAGE_COVERAGE_PROVENANCE=PASS'     'FVQ105_DEFAULT_OFF_FAIL_CLOSED=PASS'     'FVQ105_FGC31_INDEPENDENT PASS'; do
    grep -Fxq "$marker" "$out/output.txt" || { cat "$out/output.txt" >&2; fail "missing $tag marker $marker"; }
  done
  grep '^FVQ105_' "$out/output.txt" > "$out/stable.txt"
  echo "FVQ105_OPT_PASS=$tag"
}

run_one -O0 o0
run_one -O2 o2
cmp -s "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt" || {
  diff -u "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt" >&2 || true
  fail 'O0/O2 transcript mismatch'
}

# Bounded analytic construction guards.
[[ "$(grep -Eic 'call[[:space:]]+reference_tridag_backsolve' src/adapter/mod_reference_richards_accepted_step_directional_service.f90)" -eq 1 ]] || fail 'unexpected tangent backsolve count'
if grep -Eiq 'finite.?difference|centered.?difference|perturb.*solve'   src/adapter/mod_reference_richards_accepted_step_directional_service.f90   src/runtime/mod_fmr_drainage_qbot_directional_binding.f90   src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90; then
  fail 'production finite-difference derivative construction detected'
fi
if grep -Eiq 'save[[:space:]]*::|save[[:space:]]+[a-zA-Z_]'   src/solver/mod_b110_smooth_freatic_projection.f90   src/runtime/mod_fmr_drainage_qbot_directional_binding.f90   src/adapter/mod_reference_richards_accepted_step_directional_service.f90; then
  fail 'persistent SAVE state detected'
fi

cat "$BUILD/o0/output.txt"
echo 'FVQ105_O0_O2_EXACT_IDENTITY=PASS'
echo 'FVQ105_EXACT_OWNER_BLOBS=PASS'
echo 'FVQ105_BOUNDED_ANALYTIC_IMPLEMENTATION=PASS'
echo 'F-VQ105 QUALIFICATION PASS'
