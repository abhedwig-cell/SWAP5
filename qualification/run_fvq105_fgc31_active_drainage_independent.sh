#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq105-fgc31-independent-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "FVQ105_INDEPENDENT_GATE_FAIL $*" >&2; exit 31; }

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

OWNER_BASE="7eba772135f461f1299062386e32b149aa664a20"
declare -A EXPECTED=(
  ["src/solver/mod_b110_smooth_freatic_projection.f90"]="e83c1013a1d96508740619a71cfa1dbfdd665d61"
  ["src/solver/mod_soil_water_accepted_step_direction_contract.f90"]="b5a0276d2f1b2c8ffe581e68dffecdaf55a32768"
  ["src/adapter/mod_reference_richards_accepted_step_directional_service.f90"]="8ca4e08f0297a6b7d0bca1608e9a1ac4d41f4fd7"
  ["src/runtime/mod_fmr_drainage_qbot_directional_binding.f90"]="481dc8cb1af683053614de3a11c4155acb34b413"
  ["src/runtime/mod_fmr_serialized_reference_backend.f90"]="4e5491c997ed0752a4db9abd09b5ad3daf394db2"
  ["src/transaction/mod_accepted_trajectory_directional_sensitivity.f90"]="d267a763ceb697557e762c937a99b7f11cb44684"
  ["src/transaction/mod_accepted_trajectory_directional_publication.f90"]="b1be9af9ece045cac1fd17087e6b08bc615bd733"
  ["src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90"]="2d5342b45a61c9426d2b589b285050b648d141b9"
)
for path in "${!EXPECTED[@]}"; do
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "${EXPECTED[$path]}" ]] || fail "production blob drift $path $actual"
done
while IFS= read -r path; do
  case "$path" in
    qualification/test_fvq105_fgc31_active_drainage_independent.f90|qualification/run_fvq105_fgc31_active_drainage_independent.sh|qualification/F-VQ105_FGC31_ACTIVE_DRAINAGE.json|.github/workflows/f-vq105-fgc31-active-drainage-independent.yml) ;;
    *) fail "independent branch unexpected delta: $path" ;;
  esac
done < <(git diff --name-only "$OWNER_BASE..HEAD")
echo 'FVQ105_PRODUCTION_DELTA=NONE'

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     qualification/test_fvq105_fgc31_active_drainage_independent.f90 -o "$OUT/test.o" || fail "compile O$opt independent test"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test" || fail "link O$opt"
  timeout 180s "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  for marker in     'FVQ105_MULTI_SUBSTEP_ACTIVE_DRAINAGE=PASS'     'FVQ105_FIVE_POINT_PRODUCTION_FD=PASS'     'FVQ105_TANGENT_PHYSICAL_IDENTITY=PASS'     'FVQ105_DRAINAGE_COVERAGE_PROVENANCE=PASS'     'FVQ105_TERMINAL_GWL_DIRECTION=PASS'     'FVQ105_FAIL_CLOSED_INCOMPLETE_COVERAGE=PASS'     'FVQ105_NO_EXTRA_NONLINEAR_SOLVE=PASS'     'FVQ105_INDEPENDENT_ORACLE=PASS'; do
    grep -Fxq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  grep '^FVQ105_' "$OUT/output.txt" > "$OUT/signature.txt"
  echo "FVQ105_INDEPENDENT_O${opt}=PASS"
done

cmp -s "$BUILD/o0/signature.txt" "$BUILD/o2/signature.txt" || {
  diff -u "$BUILD/o0/signature.txt" "$BUILD/o2/signature.txt" >&2 || true
  fail 'O0/O2 independent signature drift'
}
echo 'FVQ105_O0_O2_EXACT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'F-VQ105 F-GC31 INDEPENDENT QUALIFICATION PASS'
