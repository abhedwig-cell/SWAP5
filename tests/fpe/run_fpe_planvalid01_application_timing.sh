#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-planvalid01-app-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/base" "$BUILD/candidate" "$BUILD/src"
trap 'rm -rf "$BUILD"' EXIT
BASE=f5ba657695156a936cb3dc8e14669f92d333753b
git fetch --no-tags --depth=1 origin "$BASE"
git show "$BASE:src/runtime/mod_fmr_runtime_core.f90" > "$BUILD/src/runtime_base.f90"

COMMON=(-std=f2008 -ffree-line-length-none -O2)
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
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  RUNTIME_CORE_PLACEHOLDER
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
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
  src/process/mod_drainage_extended_exchange.f90
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
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_fmr_groundwater_swap_participant.f90
  src/runtime/mod_fmr_groundwater_participant_registry.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
  src/runtime/mod_modflow6_linear_response_backend.f90
  src/runtime/mod_modflow6_api_binding.f90
  src/runtime/mod_groundwater_topology_composition.f90
  src/runtime/mod_groundwater_application_plan.f90
  src/runtime/mod_fmr_groundwater_application_context.f90
  src/adapter/mod_fmr_groundwater_application_c_api.f90
  src/runtime/mod_fmr_production_application_bootstrap.f90
)

compile_variant() {
  local name="$1"
  local runtime_core="$2"
  local out="$BUILD/$name"
  local objects=()
  for source in "${MODULE_SRC[@]}"; do
    if [[ "$source" == "RUNTIME_CORE_PLACEHOLDER" ]]; then source="$runtime_core"; fi
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -J "$out" -I "$out" -c tests/fpe/test_fpe_planvalid01_application_timing.f90 -o "$out/test.o"
  gfortran -O2 "${objects[@]}" "$out/test.o" -o "$out/test"
}
compile_variant base "$BUILD/src/runtime_base.f90"
compile_variant candidate src/runtime/mod_fmr_runtime_core.f90

: > "$BUILD/results.csv"
echo 'pair,variant,n,init_seconds,run_seconds,ns_per_column' >> "$BUILD/results.csv"
run_one() {
  local pair="$1" variant="$2" n="$3"
  local line
  line="$("$BUILD/$variant/test" "$n" "$pair" | grep '^PLANVALID01_APP,n=')"
  python3 - "$pair" "$variant" "$n" "$line" "$BUILD/results.csv" <<'PY'
import csv,re,sys
pair,variant,n,line,path=sys.argv[1:]
def v(k):
    m=re.search(rf'{k}=\s*([^,]+)',line)
    if not m: raise SystemExit(f'missing {k}: {line}')
    return m.group(1).strip()
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([pair,variant,n,v('init_seconds'),v('run_seconds'),v('ns_per_column')])
print(line)
PY
}
for n in 1000 10000; do
  for pair in 1 2 3 4 5; do
    if (( pair % 2 == 1 )); then
      run_one "$pair" base "$n"
      run_one "$pair" candidate "$n"
    else
      run_one "$pair" candidate "$n"
      run_one "$pair" base "$n"
    fi
  done
done

python3 - "$BUILD/results.csv" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
for n in (1000,10000):
    by={}
    for r in rows:
        if int(r['n'])==n: by.setdefault(int(r['pair']),{})[r['variant']]=r
    init_rat=[]; run_rat=[]
    for pair,v in sorted(by.items()):
        init_rat.append(float(v['candidate']['init_seconds'])/float(v['base']['init_seconds']))
        run_rat.append(float(v['candidate']['run_seconds'])/float(v['base']['run_seconds']))
    print(f'PLANVALID01_APP_PAIRED_N={n},INIT_MEAN_RATIO={statistics.mean(init_rat):.9f},INIT_MEDIAN_RATIO={statistics.median(init_rat):.9f},RUN_MEAN_RATIO={statistics.mean(run_rat):.9f},RUN_MEDIAN_RATIO={statistics.median(run_rat):.9f}')
print('PLANVALID01_APP_PAIRED=PASS')
PY
