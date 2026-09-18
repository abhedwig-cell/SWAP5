#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PRE_CANONICAL="f2d472cb0e4d935ef39f002d6f21c8d90acf4dd8"
OWNER_HEAD="fff0a8be74de3240d56a910f1b19eb4fb50146e9"
FVQ105_HEAD="6451461a20c7e6dee6631f05f825705f62bf413b"
FVQ105_STATUS_BLOB="f559a713cbb347bda3dc4f2a296927ce98bca527"

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

fail(){ echo "FCI98_ADMISSION_FAIL $*" >&2; exit 98; }

git merge-base --is-ancestor "$PRE_CANONICAL" HEAD || fail 'pre-canonical is not ancestor'

for path in "${!OWNER_BLOBS[@]}"; do
  test "$(git rev-parse "$OWNER_HEAD:$path")" = "${OWNER_BLOBS[$path]}" || fail "owner blob drift $path"
  test "$(git rev-parse "HEAD:$path")" = "${OWNER_BLOBS[$path]}" || fail "admission blob mismatch $path"
done

mapfile -t src_delta < <(git diff --name-only "$PRE_CANONICAL..HEAD" -- 'src/**' | sort)
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
test "${#src_delta[@]}" -eq "${#expected_src[@]}" || fail 'unexpected production delta count'
for i in "${!expected_src[@]}"; do
  test "${src_delta[$i]}" = "${expected_src[$i]}" || fail "production delta mismatch at $i"
done
echo 'FCI98_EXACT_EIGHT_MODULE_PRODUCTION_DELTA=PASS'

test "$(git rev-parse HEAD:qualification/F-VQ105_STATUS.json)" = "$FVQ105_STATUS_BLOB" || fail 'F-VQ105 status blob mismatch'
test "$(git rev-parse "$FVQ105_HEAD:qualification/F-VQ105_STATUS.json")" = "$FVQ105_STATUS_BLOB" || fail 'F-VQ105 immutable status mismatch'

python3 - <<'PY'
import json
from pathlib import Path
s=json.loads(Path('qualification/F-VQ105_STATUS.json').read_text())
assert s['verdict']=='INDEPENDENTLY_QUALIFIED_FOR_ADMISSION_REVIEW'
assert s['owner']['qualified_source_head']=='fff0a8be74de3240d56a910f1b19eb4fb50146e9'
assert s['independence']['verifier_production_delta']=='NONE'
assert s['independence']['owner_test_reused'] is False
assert s['independence']['production_finite_difference_runtime_fallback_admitted'] is False
assert any('lagged per accepted substep' in x for x in s['preserved_limits'])
assert any('fully implicit Newton/Jacobian drainage coupling' in x for x in s['preserved_limits'])
assert 'no MODFLOW6/XMI backend' in s['preserved_limits']
print('FCI98_FVQ105_EVIDENCE_LOCK=PASS')
PY

python3 - <<'PY'
from pathlib import Path
contract=Path('src/solver/mod_soil_water_accepted_step_direction_contract.f90').read_text()
sensitivity=Path('src/transaction/mod_accepted_trajectory_directional_sensitivity.f90').read_text()
publication=Path('src/transaction/mod_accepted_trajectory_directional_publication.f90').read_text()
projection=Path('src/solver/mod_b110_smooth_freatic_projection.f90').read_text()
binding=Path('src/runtime/mod_fmr_drainage_qbot_directional_binding.f90').read_text()
service=Path('src/adapter/mod_reference_richards_accepted_step_directional_service.f90').read_text()
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
adapter=Path('src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90').read_text()

for token in ['incoming_source_direction','incoming_sink_direction','source_sink_direction_covered']:
    assert token in contract, token
for token in ['source_sink_direction_coverage_complete','pending_source_sink_direction_covered']:
    assert token in sensitivity, token
assert 'source_sink_direction_coverage_complete = state%source_sink_direction_coverage_complete' in publication
for token in ['strict-interior-crossing-unavailable','fully-saturated-branch-excluded']:
    assert token in projection, token
for token in ['dq_dgroundwater_level * groundwater_level_direction',
              'lagged-start-gwl-to-bottom-lumped-drainage-direction']:
    assert token in binding, token
for token in ['sink_direction(i) - source_direction(i)','direction_result%source_sink_direction_covered']:
    assert token in service, token
for token in ['compose_fmr_qbot_drainage_sink_direction',
              'direction_request%incoming_sink_direction',
              'solve_result%candidate_state%groundwater_level = candidate_projected_groundwater_level']:
    assert token in backend, token
for token in ['endpoint%coverage%drainage_covered = drainage_active .and.',
              'trajectory%source_sink_direction_coverage_complete',
              'endpoint%authoritative = .false.']:
    assert token in adapter, token
print('FCI98_PRODUCTION_CONTRACT_AUDIT=PASS')
print('FCI98_LAGGED_DRAINAGE_SEMANTICS=PASS')
print('FCI98_COVERAGE_PROVENANCE=PASS')
PY

for file in   src/adapter/mod_reference_richards_accepted_step_directional_service.f90   src/runtime/mod_fmr_drainage_qbot_directional_binding.f90   src/runtime/mod_fmr_serialized_reference_backend.f90   src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90   src/solver/mod_b110_smooth_freatic_projection.f90   src/solver/mod_soil_water_accepted_step_direction_contract.f90   src/transaction/mod_accepted_trajectory_directional_publication.f90   src/transaction/mod_accepted_trajectory_directional_sensitivity.f90; do
  if grep -Eiq 'save[[:space:]]*::|save[[:space:]]+[a-zA-Z_]' "$file"; then
    fail "persistent SAVE state detected in $file"
  fi
done
if grep -Eiq 'finite.?difference|perturb.*solve'   src/runtime/mod_fmr_drainage_qbot_directional_binding.f90   src/adapter/mod_reference_richards_accepted_step_directional_service.f90   src/runtime/mod_fmr_serialized_reference_backend.f90; then
  fail 'runtime finite-difference construction detected'
fi
echo 'FCI98_BOUNDED_ANALYTIC_IMPLEMENTATION=PASS'

work="$(mktemp -d)"
trap 'rm -rf "$work"; rm -f tests/fgc/test_fgc31_active_drainage_production_tangent.f90 tests/fgc/run_fgc31_active_drainage_production_tangent.sh' EXIT

# Owner replay against the exact admission postimage. Test artifacts are donors only.
test ! -e tests/fgc/test_fgc31_active_drainage_production_tangent.f90
test ! -e tests/fgc/run_fgc31_active_drainage_production_tangent.sh
git show "$OWNER_HEAD:tests/fgc/test_fgc31_active_drainage_production_tangent.f90" > tests/fgc/test_fgc31_active_drainage_production_tangent.f90
git show "$OWNER_HEAD:tests/fgc/run_fgc31_active_drainage_production_tangent.sh" > tests/fgc/run_fgc31_active_drainage_production_tangent.sh
bash tests/fgc/run_fgc31_active_drainage_production_tangent.sh > "$work/owner.txt"
for marker in   FGC31_ACTIVE_DRAINAGE_MULTI_SUBSTEP   FGC31_ACTIVE_DRAINAGE_COVERAGE_PROVENANCE   FGC31_ACTIVE_DRAINAGE_TANGENT_PHYSICAL_IDENTITY   FGC31_ACTIVE_DRAINAGE_PRODUCTION_FD   FGC31_ACTIVE_DRAINAGE_NO_EXTRA_NONLINEAR_SOLVE   FGC31_ACTIVE_DRAINAGE_ENDPOINT_AUTHORITATIVE   FGC31_ACTIVE_DRAINAGE_PRODUCTION_O0_O2_EXACT_IDENTITY; do
  grep -q "^${marker}=PASS$" "$work/owner.txt" || fail "owner replay marker $marker"
done
cat "$work/owner.txt"
echo 'FCI98_OWNER_PRODUCTION_REPLAY=PASS'

# Independent F-VQ105 replay against the admission postimage.
git show "$FVQ105_HEAD:tests/fvq/test_fvq105_fgc31_independent.f90" > "$work/test_fvq105.f90"

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

compile_vq(){
  local opt="$1" out="$work/vq_o$1"
  mkdir -p "$out"
  local objects=() source obj
  for source in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj" || fail "VQ compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$work/test_fvq105.f90" -o "$out/test.o" || fail "VQ test compile O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test" || fail "VQ link O$opt"
  timeout 180s "$out/test" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "VQ runtime O$opt"; }
}

compile_vq 0
compile_vq 2
diff -u "$work/vq_o0/output.txt" "$work/vq_o2/output.txt"
for marker in   FVQ105_ACTIVE_DRAINAGE_MULTI_SUBSTEP   FVQ105_ACTIVE_DRAINAGE_COVERAGE_PROVENANCE   FVQ105_TANGENT_PHYSICAL_IDENTITY   FVQ105_SAME_BACKEND_CENTERED_FD   FVQ105_NO_EXTRA_NONLINEAR_SOLVE   FVQ105_ENDPOINT_AUTHORITATIVE   FVQ105_COVERAGE_FAIL_CLOSED   FVQ105_GWL_BRANCH_FAIL_CLOSED   FVQ105_INDEPENDENT_NUMERICAL_ORACLE; do
  grep -q "^${marker}=PASS$" "$work/vq_o0/output.txt" || fail "VQ replay marker $marker"
done
cat "$work/vq_o0/output.txt"

echo "FCI98_PRE_CANONICAL=PASS:$PRE_CANONICAL"
echo "FCI98_OWNER_HEAD=PASS:$OWNER_HEAD"
echo "FCI98_FVQ105_HEAD=PASS:$FVQ105_HEAD"
echo 'FCI98_INDEPENDENT_REPLAY=PASS'
echo 'FCI98_INDEPENDENT_O0_O2_IDENTITY=PASS'
echo 'FCI98_FULLY_IMPLICIT_DRAINAGE_NOT_ADMITTED=PASS'
echo 'FCI98_DECISION=QUALIFIED_FOR_CANONICAL_ADMISSION'
