#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-root-hyd01-preserve-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PPA_ROOT_HYD01_PRESERVE_FAIL $*" >&2; exit 62; }
check_blob(){
  local path="$1"
  local expected="$2"
  test "$(git rev-parse "HEAD:$path")" = "$expected" || fail "exact admitted successor drift: $path"
}

BASE=1dc12a3f47935a3639ef3fb38dc0d6338a0f44c0
PPA_ROOT_HYD02_ADMISSION=7ea315285904783225741b350be292974afeec92
PPA_ROOT_HYD02_QUALIFIED=55451eec38a877412e3eef59c3c103a33156ceee
PPA_WU04A_ADMISSION=50e7d1dece5b75d0103459d5c118d03a2665eea3
PPA_WU04A_QUALIFIED=f1fd0fa5633cea1fa5f3870eb2aa7b236d40a938
PPA_WU04B_ADMISSION=4d40b8d4b6a1df06ff97fab55497542778431290
PPA_WU04B_QUALIFIED=eb0e635975b77ec92084e1416038b1bc1f8232bc

git merge-base --is-ancestor "$BASE" HEAD || fail "branch is not descended from frozen authority base"

expected_src=(
  src/solver/mod_reference_richards_temporal_indicator.f90
)

if git merge-base --is-ancestor "$PPA_ROOT_HYD02_ADMISSION" HEAD; then
  git merge-base --is-ancestor "$PPA_ROOT_HYD02_QUALIFIED" "$PPA_ROOT_HYD02_ADMISSION" || \
    fail "PPA-ROOT-HYD02 qualified head not contained by canonical admission"
  expected_src+=(
    src/adapter/mod_reference_richards_accepted_step_directional_service.f90
    src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
    src/solver/mod_soil_water_accepted_step_direction_contract.f90
    src/transaction/mod_accepted_trajectory_directional_publication.f90
    src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  )
  check_blob src/adapter/mod_reference_richards_accepted_step_directional_service.f90 e6ca1504c0f6511430c9b4d6866f4ee3804639a5
  check_blob src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90 a9856506d29ebe73f1ac02af2670a8873626be23
  check_blob src/solver/mod_soil_water_accepted_step_direction_contract.f90 5418b6a1a9f651e818678f347c9cd8399693eb82
  check_blob src/transaction/mod_accepted_trajectory_directional_publication.f90 a74c1877c0bfdd1e6df070f78928d9509ef2d0da
  check_blob src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 484c2bcb74ac78167ba0176ea7964dc525e22bf4
  echo 'PPA_ROOT_HYD01_PRESERVE_ROOT_HYD02_EXACT_SUCCESSOR=PASS'
fi

if git merge-base --is-ancestor "$PPA_WU04B_ADMISSION" HEAD; then
  git merge-base --is-ancestor "$PPA_WU04B_QUALIFIED" "$PPA_WU04B_ADMISSION" || \
    fail "PPA-WU04-B qualified head not contained by canonical admission"
  expected_src+=(
    src/adapter/mod_ppa_wu04a_black_forcing_adapter.f90
    src/adapter/mod_ppa_wu04b_boesten_forcing_adapter.f90
    src/process/mod_restricted_surface_evaporation.f90
    src/runtime/mod_fmr_production_application_bootstrap.f90
    src/runtime/mod_fmr_restart_state_contract.f90
    src/runtime/mod_fmr_runtime_core.f90
    src/runtime/mod_fmr_serialized_reference_backend.f90
  )
  check_blob src/adapter/mod_ppa_wu04a_black_forcing_adapter.f90 eb8cb6f34db60258b099b8081154cab525770143
  check_blob src/adapter/mod_ppa_wu04b_boesten_forcing_adapter.f90 0dc304d3b943fd4a0918cbf3ab2c45974fc53e0a
  check_blob src/process/mod_restricted_surface_evaporation.f90 1f795f0baaa3ed86272a1feabc3f1a6463b3ce77
  check_blob src/runtime/mod_fmr_production_application_bootstrap.f90 356b3825a8ba13af1fed385ab17ffdb330b1058f
  check_blob src/runtime/mod_fmr_restart_state_contract.f90 ddcb880dbdbf1d6b41c8721f931df9a2c8bc121a
  check_blob src/runtime/mod_fmr_runtime_core.f90 dc1dbffab96542ee09be5f923cea65628864d87b
  check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 9bd344a83afd5e10b96178933362dbb7eeea4f30
  echo 'PPA_ROOT_HYD01_PRESERVE_WU04B_EXACT_SUCCESSOR=PASS'
elif git merge-base --is-ancestor "$PPA_WU04A_ADMISSION" HEAD; then
  git merge-base --is-ancestor "$PPA_WU04A_QUALIFIED" "$PPA_WU04A_ADMISSION" || \
    fail "PPA-WU04-A qualified head not contained by canonical admission"
  expected_src+=(
    src/adapter/mod_ppa_wu04a_black_forcing_adapter.f90
    src/process/mod_restricted_surface_evaporation.f90
    src/runtime/mod_fmr_production_application_bootstrap.f90
    src/runtime/mod_fmr_restart_state_contract.f90
    src/runtime/mod_fmr_runtime_core.f90
    src/runtime/mod_fmr_serialized_reference_backend.f90
  )
  check_blob src/adapter/mod_ppa_wu04a_black_forcing_adapter.f90 eb8cb6f34db60258b099b8081154cab525770143
  check_blob src/process/mod_restricted_surface_evaporation.f90 a7b9f5271ac0582420e883a62c6e13672dc190e9
  check_blob src/runtime/mod_fmr_production_application_bootstrap.f90 9ae38276a353bd08f5d971d6368eed41967086b6
  check_blob src/runtime/mod_fmr_restart_state_contract.f90 665d90cb82485dec485be68694f77e0fcd03145c
  check_blob src/runtime/mod_fmr_runtime_core.f90 29cff34a37c13143ce069486251bc0b858cadf48
  check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 b1ba0549ef9149c4261b8a595c8782be01726c43
  echo 'PPA_ROOT_HYD01_PRESERVE_WU04A_EXACT_SUCCESSOR=PASS'
fi

changed_src="$(git diff --name-only "$BASE"..HEAD -- src | sort)"
expected_src_sorted="$(printf '%s\n' "${expected_src[@]}" | sort)"
[[ "$changed_src" == "$expected_src_sorted" ]] || {
  printf 'Observed src delta:\n%s\nExpected src delta:\n%s\n' "$changed_src" "$expected_src_sorted" >&2
  fail "unexpected production source delta"
}
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
for name in fsi38 fsi25; do
  diff -u "$BUILD/o0/$name.txt" "$BUILD/o2/$name.txt" || fail "$name O0/O2 output identity"
done

cat "$BUILD/o0/fsi38.txt"
cat "$BUILD/o0/fsi25.txt"
echo 'PPA_ROOT_HYD01_PRESERVE_FSI38=PASS'
echo 'PPA_ROOT_HYD01_PRESERVE_FSI25=PASS'
echo 'PPA_ROOT_HYD01_PRESERVATION_GATE=PASS'
