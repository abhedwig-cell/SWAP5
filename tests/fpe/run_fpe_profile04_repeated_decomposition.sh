#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-profile04-decomp-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/mod"
trap 'rm -rf "$BUILD"' EXIT

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
  src/runtime/mod_fmr_runtime_core.f90
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
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_direct_retention_provider.f90
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

objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/mod/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD/mod" -I "$BUILD/mod" -c "$source" -o "$obj"
  objects+=("$obj")
done

gfortran "${COMMON[@]}" -J "$BUILD/mod" -I "$BUILD/mod" \
  -c tests/fpe/test_fpe_planvalid01_application_timing.f90 -o "$BUILD/app.o"
gfortran -O2 "${objects[@]}" "$BUILD/app.o" -o "$BUILD/app"

gfortran "${COMMON[@]}" -J "$BUILD/mod" -I "$BUILD/mod" \
  -c tests/fpe/test_fpe_profile03_h03_application_host_timing.f90 -o "$BUILD/backend.o"
gfortran -O2 "${objects[@]}" "$BUILD/backend.o" -o "$BUILD/backend"

APP="$BUILD/app.csv"
BACK="$BUILD/backend.csv"
echo 'rep,n,ns_per_column,solver_calls_per_column,nonlinear_iterations_per_column,jacobian_builds_per_column,linear_solves_per_column,headcalc_calls_per_column,backtracking_attempts_per_column' > "$APP"
echo 'rep,mode,ns_per_interval,nonlinear_iterations_per_solve,constitutive_evaluations_per_solve' > "$BACK"

parse_app() {
  local rep="$1" n="$2" line
  line="$("$BUILD/app" "$n" "$rep" | grep '^PLANVALID01_APP,n=')"
  python3 - "$rep" "$n" "$line" "$APP" <<'PY'
import csv,re,sys
rep,n,line,path=sys.argv[1:]
n_i=int(n)
def v(k):
    m=re.search(rf'{k}=\s*([^,]+)',line)
    if not m: raise SystemExit(f'missing {k}: {line}')
    return m.group(1).strip()
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([
        rep,n,v('ns_per_column'),
        float(v('solver_calls'))/n_i,
        float(v('nonlinear_iterations'))/n_i,
        float(v('jacobian_builds'))/n_i,
        float(v('linear_solves'))/n_i,
        float(v('headcalc_calls'))/n_i,
        float(v('backtracking_attempts'))/n_i,
    ])
print(line)
PY
}

parse_backend() {
  local rep="$1" mode="$2" line
  line="$("$BUILD/backend" 5000 "$mode" zero-waste-paired | grep '^PROFILE03_E1_TIMING')"
  python3 - "$rep" "$mode" "$line" "$BACK" <<'PY'
import csv,re,sys
rep,mode,line,path=sys.argv[1:]
def v(k):
    m=re.search(rf'{k}=\s*([^,]+)',line)
    if not m: raise SystemExit(f'missing {k}: {line}')
    return m.group(1).strip()
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([rep,mode,v('ns_per_interval'),v('nonlinear_iterations_per_solve'),v('constitutive_evaluations_per_solve')])
print(line)
PY
}

for rep in 1 2 3 4 5; do
  parse_app "$rep" 1000
  parse_app "$rep" 10000
  if (( rep % 2 == 1 )); then
    parse_backend "$rep" reference
    parse_backend "$rep" directional
  else
    parse_backend "$rep" directional
    parse_backend "$rep" reference
  fi
done

python3 - "$APP" "$BACK" <<'PY'
import csv,statistics,sys
app=list(csv.DictReader(open(sys.argv[1])))
back=list(csv.DictReader(open(sys.argv[2])))

def med(xs): return statistics.median(xs)

for n in (1000,10000):
    rows=[r for r in app if int(r['n'])==n]
    vals=[float(r['ns_per_column']) for r in rows]
    print(f'PROFILE04_DECOMP_APP_N={n}|MEDIAN_NS_PER_COLUMN={med(vals):.6f}|MIN={min(vals):.6f}|MAX={max(vals):.6f}')
    for key in ('solver_calls_per_column','nonlinear_iterations_per_column','jacobian_builds_per_column',
                'linear_solves_per_column','headcalc_calls_per_column','backtracking_attempts_per_column'):
        uniq=sorted({round(float(r[key]),12) for r in rows})
        print(f'PROFILE04_DECOMP_APP_DIAG_N={n}|{key.upper()}={uniq}')

ref=[float(r['ns_per_interval']) for r in back if r['mode']=='reference']
dire=[float(r['ns_per_interval']) for r in back if r['mode']=='directional']
ref_med=med(ref); dir_med=med(dire)
print(f'PROFILE04_DECOMP_BACKEND_REFERENCE_MEDIAN_NS={ref_med:.6f}|MIN={min(ref):.6f}|MAX={max(ref):.6f}')
print(f'PROFILE04_DECOMP_BACKEND_DIRECTIONAL_MEDIAN_NS={dir_med:.6f}|MIN={min(dire):.6f}|MAX={max(dire):.6f}')
print(f'PROFILE04_DECOMP_DIRECTIONAL_OVER_REFERENCE_RATIO={dir_med/ref_med:.9f}')
print(f'PROFILE04_DECOMP_DIRECTIONAL_INCREMENT_PERCENT={(dir_med/ref_med-1.0)*100.0:.6f}')

app10=med([float(r['ns_per_column']) for r in app if int(r['n'])==10000])
print(f'PROFILE04_DECOMP_REFERENCE_BACKEND_SHARE_N10000={ref_med/app10:.9f}')
print(f'PROFILE04_DECOMP_REFERENCE_BACKEND_PERCENT_N10000={100.0*ref_med/app10:.6f}')
print(f'PROFILE04_DECOMP_RESIDUAL_APP_WRAPPER_PERCENT_N10000={100.0*(1.0-ref_med/app10):.6f}')

ref_iters=sorted({r['nonlinear_iterations_per_solve'] for r in back if r['mode']=='reference'})
ref_const=sorted({r['constitutive_evaluations_per_solve'] for r in back if r['mode']=='reference'})
dir_iters=sorted({r['nonlinear_iterations_per_solve'] for r in back if r['mode']=='directional'})
dir_const=sorted({r['constitutive_evaluations_per_solve'] for r in back if r['mode']=='directional'})
print(f'PROFILE04_DECOMP_BACKEND_DIAG|REFERENCE_NONLINEAR={ref_iters}|REFERENCE_CONSTITUTIVE={ref_const}|DIRECTIONAL_NONLINEAR={dir_iters}|DIRECTIONAL_CONSTITUTIVE={dir_const}')
print('FPE_PROFILE04_REPEATED_DECOMPOSITION=PASS')
PY
