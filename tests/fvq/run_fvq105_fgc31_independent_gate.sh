#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CANONICAL="d67a96fd576dcd1c5a30eb766c5aa1a503e10cf0"
OWNER_BASE="878ca73649c9a2e98ca81d45c3ecec2717604ba3"
OWNER_HEAD="fff0a8be74de3240d56a910f1b19eb4fb50146e9"

declare -A OWNER_BLOBS=(
  [src/adapter/mod_reference_richards_accepted_step_directional_service.f90]="8ca4e08f0297a6b7d0bca1608e9a1ac4d41f4fd7"
  [src/runtime/mod_fmr_drainage_qbot_directional_binding.f90]="481dc8cb1af683053614de3a11c4155acb34b413"
  [src/runtime/mod_fmr_serialized_reference_backend.f90]="4e5491c997ed0752a4db9abd09b5ad3daf394db2"
  [src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90]="2d5342b45a61c9426d2b589b285050b648d141b9"
  [src/solver/mod_b110_smooth_freatic_projection.f90]="e83c1013a1d96508740619a71cfa1dbfdd665d61"
  [src/solver/mod_soil_water_accepted_step_direction_contract.f90]="b5a0276d2f1b2c8ffe581e68dffecdaf55a32768"
  [src/transaction/mod_accepted_trajectory_directional_publication.f90]="b1be9af9ece045cac1fd17087e6b08bc615bd733"
  [src/transaction/mod_accepted_trajectory_directional_sensitivity.f90]="d267a763ceb697557e762c937a99b7f11cb44684"
)

fail(){ echo "FVQ105_QUALIFICATION_FAIL $*" >&2; exit 105; }

git merge-base --is-ancestor "$OWNER_BASE" "$CANONICAL"
git merge-base --is-ancestor "$OWNER_BASE" "$OWNER_HEAD"
test "$(git merge-base "$OWNER_BASE" "$OWNER_HEAD")" = "$OWNER_BASE"

for path in "${!OWNER_BLOBS[@]}"; do
  test "$(git rev-parse "$OWNER_HEAD:$path")" = "${OWNER_BLOBS[$path]}" || fail "owner blob drift: $path"
done

mapfile -t owner_src_delta < <(git diff --name-only "$OWNER_BASE..$OWNER_HEAD" -- 'src/**' | sort)
expected_src=(
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
)
test "${#owner_src_delta[@]}" -eq "${#expected_src[@]}" || fail "unexpected owner source delta size"
for i in "${!expected_src[@]}"; do
  test "${owner_src_delta[$i]}" = "${expected_src[$i]}" || fail "owner source delta mismatch at $i"
done

if git diff --name-only "$CANONICAL..HEAD" -- 'src/**' | grep -q .; then
  fail 'verifier branch modifies production source'
fi
while IFS= read -r path; do
  case "$path" in
    tests/fvq/test_fvq105_fgc31_independent.f90|tests/fvq/run_fvq105_fgc31_independent_gate.sh|.github/workflows/f-vq105-fgc31-independent.yml|qualification/F-VQ105_STATUS.json) ;;
    "") ;;
    *) fail "unexpected verifier path: $path" ;;
  esac
done < <(git diff --name-only "$CANONICAL..HEAD")

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/owner"
for path in "${!OWNER_BLOBS[@]}"; do
  git show "$OWNER_HEAD:$path" > "$work/owner/$(basename "$path")"
done

python3 - "$work/owner" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
contract=(root/'mod_soil_water_accepted_step_direction_contract.f90').read_text()
sensitivity=(root/'mod_accepted_trajectory_directional_sensitivity.f90').read_text()
publication=(root/'mod_accepted_trajectory_directional_publication.f90').read_text()
projection=(root/'mod_b110_smooth_freatic_projection.f90').read_text()
binding=(root/'mod_fmr_drainage_qbot_directional_binding.f90').read_text()
service=(root/'mod_reference_richards_accepted_step_directional_service.f90').read_text()
backend=(root/'mod_fmr_serialized_reference_backend.f90').read_text()
adapter=(root/'mod_modflow6_swap_predictor_tangent_adapter.f90').read_text()

for token in ['incoming_source_direction', 'incoming_sink_direction', 'source_sink_direction_covered']:
    assert token in contract, token
for token in ['source_sink_direction_coverage_complete', 'pending_source_sink_direction_covered']:
    assert token in sensitivity, token
assert 'source_sink_direction_coverage_complete = state%source_sink_direction_coverage_complete' in publication
for token in ['B110_GWL_PROJECTION_OK', 'strict-interior-crossing-unavailable', 'fully-saturated-branch-excluded']:
    assert token in projection, token
for token in ['compose_fmr_qbot_drainage_sink_direction', 'dq_dgroundwater_level * groundwater_level_direction',
              'lagged-start-gwl-to-bottom-lumped-drainage-direction']:
    assert token in binding, token
for token in ['sink_direction(i) - source_direction(i)', 'incoming_sink_direction',
              'source_sink_direction_covered = allocated(direction_request%incoming_source_direction) .or.']:
    assert token in service, token
for token in ['drainage_qbot_smooth_freatic_projection', 'compose_fmr_qbot_drainage_sink_direction',
              'direction_request%incoming_sink_direction', 'project_fmr_qbot_smooth_groundwater_level',
              'solve_result%candidate_state%groundwater_level = candidate_projected_groundwater_level']:
    assert token in backend, token
for token in ['endpoint%coverage%drainage_covered = drainage_active .and.',
              'trajectory%source_sink_direction_coverage_complete',
              'if (.not. endpoint%coverage%tangent_complete())']:
    assert token in adapter, token
print('FVQ105_OWNER_STATIC_CONTRACT=PASS')
print('FVQ105_LAGGED_DRAINAGE_WIRING=PASS')
print('FVQ105_COVERAGE_PROVENANCE_STATIC=PASS')
PY

for file in "$work/owner"/*.f90; do
  if grep -Eiq 'save[[:space:]]*::|save[[:space:]]+[a-zA-Z_]' "$file"; then
    fail "persistent SAVE state in donor $(basename "$file")"
  fi
done
if grep -Eiq 'finite.?difference|perturb.*solve'     "$work/owner/mod_fmr_drainage_qbot_directional_binding.f90"     "$work/owner/mod_reference_richards_accepted_step_directional_service.f90"     "$work/owner/mod_fmr_serialized_reference_backend.f90"; then
  fail 'production finite-difference derivative construction detected'
fi

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  "$work/owner/mod_soil_water_accepted_step_direction_contract.f90"
  "$work/owner/mod_accepted_trajectory_directional_sensitivity.f90"
  "$work/owner/mod_accepted_trajectory_directional_publication.f90"
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
  "$work/owner/mod_b110_smooth_freatic_projection.f90"
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
  "$work/owner/mod_fmr_drainage_qbot_directional_binding.f90"
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
  "$work/owner/mod_reference_richards_accepted_step_directional_service.f90"
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
  "$work/owner/mod_fmr_serialized_reference_backend.f90"
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  "$work/owner/mod_modflow6_swap_predictor_tangent_adapter.f90"
)

compile_and_run(){
  local opt="$1"
  local out="$work/o$opt"
  mkdir -p "$out"
  local objects=()
  local source obj
  for source in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out"     -c tests/fvq/test_fvq105_fgc31_independent.f90 -o "$out/test.o" || fail "compile O$opt verifier"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test" || fail "link O$opt verifier"
  timeout 180s "$out/test" > "$out/output.txt" 2>&1 || {
    cat "$out/output.txt" >&2
    fail "runtime O$opt verifier"
  }
}

compile_and_run 0
compile_and_run 2
diff -u "$work/o0/output.txt" "$work/o2/output.txt"

for marker in   FVQ105_ACTIVE_DRAINAGE_MULTI_SUBSTEP   FVQ105_ACTIVE_DRAINAGE_COVERAGE_PROVENANCE   FVQ105_TANGENT_PHYSICAL_IDENTITY   FVQ105_SAME_BACKEND_CENTERED_FD   FVQ105_NO_EXTRA_NONLINEAR_SOLVE   FVQ105_ENDPOINT_AUTHORITATIVE   FVQ105_COVERAGE_FAIL_CLOSED   FVQ105_GWL_BRANCH_FAIL_CLOSED   FVQ105_INDEPENDENT_NUMERICAL_ORACLE; do
  grep -Fxq "${marker}=PASS" "$work/o0/output.txt" || fail "missing marker $marker"
done

cat "$work/o0/output.txt"
echo "FVQ105_CANONICAL_BASE=PASS:$CANONICAL"
echo "FVQ105_OWNER_HEAD=PASS:$OWNER_HEAD"
for path in "${!OWNER_BLOBS[@]}"; do
  echo "FVQ105_OWNER_BLOB=PASS:$path:${OWNER_BLOBS[$path]}"
done
echo 'FVQ105_VERIFIER_PRODUCTION_DELTA=PASS:NONE'
echo 'FVQ105_O0_O2_IDENTITY=PASS'
echo 'FVQ105_DECISION=INDEPENDENTLY_QUALIFIED_FOR_ADMISSION_REVIEW'
