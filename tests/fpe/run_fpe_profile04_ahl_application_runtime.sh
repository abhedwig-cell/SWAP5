#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-profile04-ahl-app-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fpe/test_fpe_planvalid01_application_timing.f90").read_text()
src=src.replace(
    "  character(len=32) :: arg\n",
    "  character(len=32) :: arg,mode\n  logical :: use_direct\n")
src=src.replace(
    "  call get_command_argument(1,arg); read(arg,*) n\n"
    "  call get_command_argument(2,arg); read(arg,*) rep\n"
    "  if(n<=0 .or. rep<=0) error stop 'PROFILE02 baseline requires N>0 and rep>0'\n\n"
    "  call build_config(config,n)\n",
    "  call get_command_argument(1,mode)\n"
    "  call get_command_argument(2,arg); read(arg,*) n\n"
    "  call get_command_argument(3,arg); read(arg,*) rep\n"
    "  select case(trim(mode))\n"
    "  case('analytical'); use_direct=.false.\n"
    "  case('direct'); use_direct=.true.\n"
    "  case default; error stop 'PROFILE04 AHL mode must be analytical or direct'\n"
    "  end select\n"
    "  if(n<=0 .or. rep<=0) error stop 'PROFILE04 AHL requires N>0 and rep>0'\n\n"
    "  call build_config(config,n,use_direct)\n")
src=src.replace(
    "  subroutine build_config(value,count)\n"
    "    type(fmr_production_application_config_t),intent(out) :: value\n"
    "    integer,intent(in) :: count\n",
    "  subroutine build_config(value,count,use_direct)\n"
    "    type(fmr_production_application_config_t),intent(out) :: value\n"
    "    integer,intent(in) :: count\n"
    "    logical,intent(in) :: use_direct\n")
src=src.replace(
    "      call initialize_parameters(value%tiles(k)%parameters,4000000_int64+int(k,int64))\n",
    "      call initialize_parameters(value%tiles(k)%parameters,4000000_int64+int(k,int64),use_direct)\n")
src=src.replace(
    "  subroutine initialize_parameters(p,id)\n"
    "    type(fmr_b110_physical_parameters_t),intent(out) :: p\n"
    "    integer(int64),intent(in) :: id\n",
    "  subroutine initialize_parameters(p,id,use_direct)\n"
    "    type(fmr_b110_physical_parameters_t),intent(out) :: p\n"
    "    integer(int64),intent(in) :: id\n"
    "    logical,intent(in) :: use_direct\n")
src=src.replace(
    "    p%bottom_mode=7\n",
    "    p%bottom_mode=7\n    p%direct_retention_active=use_direct\n")
Path(sys.argv[1]).write_text(src)
PY

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
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$BUILD/test.f90" -o "$BUILD/test.o"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

RESULT="$BUILD/results.csv"
echo 'pair,mode,n,ns,solver_calls,accepted_substeps,nonlinear,jacobian,linear,headcalc,retries,backtrack,residual' > "$RESULT"
run_one() {
  local pair="$1" mode="$2" n="$3" line
  line="$("$BUILD/test" "$mode" "$n" "$pair" | grep '^PLANVALID01_APP,n=')"
  python3 - "$pair" "$mode" "$n" "$line" "$RESULT" <<'PY'
import csv,re,sys
pair,mode,n,line,path=sys.argv[1:]
def v(k):
    m=re.search(rf'{k}=\s*([^,]+)',line)
    if not m: raise SystemExit(f'missing {k}: {line}')
    return m.group(1).strip()
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([pair,mode,n,v('ns_per_column'),v('solver_calls'),v('accepted_substeps'),
        v('nonlinear_iterations'),v('jacobian_builds'),v('linear_solves'),v('headcalc_calls'),
        v('internal_retries'),v('backtracking_attempts'),v('max_mass_residual')])
print(line)
PY
}

for n in 1000 10000; do
  for pair in 1 2 3 4 5; do
    if (( pair % 2 == 1 )); then
      run_one "$pair" analytical "$n"
      run_one "$pair" direct "$n"
    else
      run_one "$pair" direct "$n"
      run_one "$pair" analytical "$n"
    fi
  done
done

python3 - "$RESULT" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
diag=('solver_calls','accepted_substeps','nonlinear','jacobian','linear','headcalc','retries','backtrack','residual')
for n in (1000,10000):
    by={}
    for r in rows:
        if int(r['n'])==n: by.setdefault(int(r['pair']),{})[r['mode']]=r
    ratios=[]; av=[]; dv=[]
    for pair,p in sorted(by.items()):
        if set(p)!={'analytical','direct'}: raise SystemExit(f'incomplete pair n={n} pair={pair}')
        a,d=p['analytical'],p['direct']
        for k in diag:
            if a[k]!=d[k]: raise SystemExit(f'diagnostic drift n={n} pair={pair} key={k}: {a[k]} != {d[k]}')
        aa=float(a['ns']); dd=float(d['ns'])
        av.append(aa); dv.append(dd); ratios.append(dd/aa)
    print(f'PROFILE04_AHL_APP_N={n}|ANALYTICAL_MEDIAN_NS={statistics.median(av):.6f}|DIRECT_MEDIAN_NS={statistics.median(dv):.6f}|PAIRED_MEAN_RATIO={statistics.mean(ratios):.9f}|PAIRED_MEDIAN_RATIO={statistics.median(ratios):.9f}|PAIRS={len(ratios)}')
    print(f'PROFILE04_AHL_APP_SPEEDUP_N={n}|MEAN_PERCENT={(1-statistics.mean(ratios))*100:.6f}|MEDIAN_PERCENT={(1-statistics.median(ratios))*100:.6f}')
print('FPE_PROFILE04_AHL_APPLICATION_RUNTIME=PASS')
PY
