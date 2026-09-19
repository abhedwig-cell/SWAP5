#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-root-hyd02-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PPA_ROOT_HYD02_FAIL $*" >&2; exit 62; }

BASE=8cf184955a0f366ef85bc38dd64c19aa639b7098
FGC31_OWNER=fff0a8be74de3240d56a910f1b19eb4fb50146e9

git merge-base --is-ancestor "$BASE" HEAD || fail "branch not descended from frozen canonical base"
mapfile -t changed_src < <(git diff --name-only "$BASE"..HEAD -- src | sort)
expected_src=(
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
)
[[ "${#changed_src[@]}" -eq "${#expected_src[@]}" ]] || { printf '%s\n' "${changed_src[@]}" >&2; fail "unexpected production delta count"; }
for i in "${!expected_src[@]}"; do
  [[ "${changed_src[$i]}" == "${expected_src[$i]}" ]] || fail "unexpected production delta at $i"
done
git diff --quiet "$BASE"..HEAD -- reference || fail "reference source changed"

grep -Fq "type is (b110_root_sink_provider_t)" src/adapter/mod_reference_richards_accepted_step_directional_service.f90 || fail "concrete root-provider guard missing"
grep -Fq "class default" src/adapter/mod_reference_richards_accepted_step_directional_service.f90 || fail "root fail-closed class default missing"
grep -Fq "root_sink_direction_coverage_complete" src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 || fail "trajectory root coverage missing"
grep -Fq "trajectory%root_sink_direction_coverage_complete" src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90 || fail "endpoint root coverage provenance missing"
! grep -Eiq 'finite.?difference|perturb.*solve' src/adapter/mod_reference_richards_accepted_step_directional_service.f90 src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90 || fail "runtime finite-difference construction detected"
echo 'PPA_ROOT_HYD02_STATIC_SCOPE=PASS'
echo 'PPA_ROOT_HYD02_UNSUPPORTED_ROOT_FAIL_CLOSED_SOURCE=PASS'

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
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
)

git cat-file -e "${FGC31_OWNER}^{commit}" 2>/dev/null || git fetch --no-tags origin "$FGC31_OWNER" >/dev/null 2>&1 || fail "cannot fetch F-GC31 owner"
git show "$FGC31_OWNER:tests/fgc/test_fgc31_active_drainage_production_tangent.f90" > "$BUILD/test_fgc31.f90"

run_one(){
  local opt="$1" out="$BUILD/o$1"
  mkdir -p "$out"
  local objects=() source obj
  for source in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fapp/test_ppa_root_hyd02_prescribed_root_tangent.f90 -o "$out/hyd02.o" || fail "compile HYD02 O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/hyd02.o" -o "$out/hyd02" || fail "link HYD02 O$opt"
  timeout 180s "$out/hyd02" > "$out/hyd02.txt" 2>&1 || { cat "$out/hyd02.txt" >&2; fail "HYD02 runtime O$opt"; }

  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fkt/test_fkt21_accepted_trajectory_direction.f90 -o "$out/fkt21.o" || fail "compile FKT21 O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/fkt21.o" -o "$out/fkt21" || fail "link FKT21 O$opt"
  "$out/fkt21" > "$out/fkt21.txt" 2>&1 || { cat "$out/fkt21.txt" >&2; fail "FKT21 runtime O$opt"; }

  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/test_fgc31.f90" -o "$out/fgc31.o" || fail "compile FGC31 O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/fgc31.o" -o "$out/fgc31" || fail "link FGC31 O$opt"
  timeout 180s "$out/fgc31" > "$out/fgc31.txt" 2>&1 || { cat "$out/fgc31.txt" >&2; fail "FGC31 runtime O$opt"; }

  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fapp/test_ppa_root_hyd01_sink_equivalence.f90 -o "$out/hyd01.o" || fail "compile HYD01 O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/hyd01.o" -o "$out/hyd01" || fail "link HYD01 O$opt"
  timeout 180s "$out/hyd01" > "$out/hyd01.txt" 2>&1 || { cat "$out/hyd01.txt" >&2; fail "HYD01 runtime O$opt"; }
}

run_one 0
run_one 2

for marker in   PPA_ROOT_HYD02_ROOT_GENERIC_PHYSICAL_IDENTITY=PASS   PPA_ROOT_HYD02_ROOT_GENERIC_DIRECTIONAL_IDENTITY=PASS   PPA_ROOT_HYD02_ROOT_COVERAGE_PROVENANCE=PASS   PPA_ROOT_HYD02_MODFLOW_ENDPOINT_AUTHORITATIVE=PASS   PPA_ROOT_HYD02_NO_EXTRA_NONLINEAR_SOLVE=PASS   PPA_ROOT_HYD02_GATE=PASS; do
  grep -Fxq "$marker" "$BUILD/o0/hyd02.txt" || { cat "$BUILD/o0/hyd02.txt" >&2; fail "missing HYD02 marker $marker"; }
done
grep -Fq 'FKT21_ACCEPTED_TRAJECTORY_DIRECTION PASS' "$BUILD/o0/fkt21.txt" || fail "FKT21 preservation"
for marker in   FGC31_ACTIVE_DRAINAGE_MULTI_SUBSTEP=PASS   FGC31_ACTIVE_DRAINAGE_COVERAGE_PROVENANCE=PASS   FGC31_ACTIVE_DRAINAGE_ENDPOINT_AUTHORITATIVE=PASS; do
  grep -Fxq "$marker" "$BUILD/o0/fgc31.txt" || { cat "$BUILD/o0/fgc31.txt" >&2; fail "FGC31 preservation $marker"; }
done
grep -Fq 'PPA_ROOT_HYD01_R1_ROOT_GENERIC_TEMPORAL_EQUIVALENCE=PASS' "$BUILD/o0/hyd01.txt" || fail "HYD01 preservation"

for name in hyd02 fkt21 fgc31 hyd01; do
  diff -u "$BUILD/o0/$name.txt" "$BUILD/o2/$name.txt" || fail "$name O0/O2 output drift"
done

cat "$BUILD/o0/hyd02.txt"
echo 'PPA_ROOT_HYD02_FKT21_PRESERVATION=PASS'
echo 'PPA_ROOT_HYD02_FGC31_PRESERVATION=PASS'
echo 'PPA_ROOT_HYD02_HYD01_PRESERVATION=PASS'
echo 'PPA_ROOT_HYD02_O0_O2_IDENTITY=PASS'
echo 'PPA_ROOT_HYD02_QUALIFICATION=PASS'
