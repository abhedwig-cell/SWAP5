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
src=Path("tests/fahl/test_fahl49_application_scale.f90").read_text()
needle="""  write(*,'(A)') 'FAHL49_APP_INIT=PASS'
  call app%close(status)
"""
replacement="""  write(*,'(A)') 'FAHL49_APP_INIT=PASS'

  call system_clock(c0)
  call app%run_standalone(T0,T1,results,status)
  call system_clock(c1)
  if(status/=FMR_APP_BOOT_OK) error stop 'PROFILE04 AHL application run failed'
  run_s=real(c1-c0,real64)/real(rate,real64)
  if(.not.allocated(results) .or. size(results)/=n) error stop 'PROFILE04 AHL result shape'
  if(.not.all(results%completed) .or. .not.all(results%committed)) error stop 'PROFILE04 AHL incomplete result'
  completed_count=count(results%completed)
  committed_count=count(results%committed)
  solver_calls=count(results%solver_executed)
  accepted_substeps=sum(results%accepted_substeps)
  nonlinear_iterations=sum(results%solver_nonlinear_iterations)
  jacobian_builds=sum(results%solver_jacobian_builds)
  linear_solves=sum(results%solver_linear_solves)
  headcalc_calls=sum(results%solver_headcalc_calls)
  internal_retries=sum(results%solver_internal_retries)
  backtracking_attempts=sum(results%solver_backtracking_attempts)
  max_residual=maxval(abs(results%mass%residual))
  if(max_residual>TOL) error stop 'PROFILE04 AHL hard mass gate'
  write(*,'(*(g0))') 'PROFILE04_AHL_APP_RUN|MODE=',trim(mode),'|N=',n,'|REP=',rep, &
       '|RUN=',run_s,'|NS_PER_COLUMN=',1.0e9_real64*run_s/real(n,real64), &
       '|COMPLETED=',completed_count,'|COMMITTED=',committed_count,'|SOLVER_CALLS=',solver_calls, &
       '|ACCEPTED_SUBSTEPS=',accepted_substeps,'|NONLINEAR=',nonlinear_iterations, &
       '|JACOBIAN=',jacobian_builds,'|LINEAR=',linear_solves,'|HEADCALC=',headcalc_calls, &
       '|INTERNAL_RETRIES=',internal_retries,'|BACKTRACK=',backtracking_attempts, &
       '|MAX_MASS_RESIDUAL=',max_residual

  call app%close(status)
"""
if needle not in src:
    raise SystemExit("expected F-AHL49 close block not found")
Path(sys.argv[1]).write_text(src.replace(needle,replacement))
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
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
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

RESULT="$BUILD/results.txt"
: > "$RESULT"
for n in 1000 10000; do
  for rep in 1 2 3 4 5; do
    if (( rep % 2 == 1 )); then
      "$BUILD/test" analytical "$n" "$rep" | tee -a "$RESULT"
      "$BUILD/test" direct "$n" "$rep" | tee -a "$RESULT"
    else
      "$BUILD/test" direct "$n" "$rep" | tee -a "$RESULT"
      "$BUILD/test" analytical "$n" "$rep" | tee -a "$RESULT"
    fi
  done
done

python3 - "$RESULT" <<'PY'
import collections,statistics,sys
rows=collections.defaultdict(lambda: collections.defaultdict(dict))
for line in open(sys.argv[1]):
    if not line.startswith('PROFILE04_AHL_APP_RUN|'): continue
    d={}
    for part in line.strip().split('|')[1:]:
        k,v=part.split('=',1); d[k]=v
    rows[int(d['N'])][int(d['REP'])][d['MODE']]=d

diag=('COMPLETED','COMMITTED','SOLVER_CALLS','ACCEPTED_SUBSTEPS','NONLINEAR','JACOBIAN',
      'LINEAR','HEADCALC','INTERNAL_RETRIES','BACKTRACK')
for n in (1000,10000):
    ratios=[]
    ans=[]; dirs=[]
    for rep,pair in sorted(rows[n].items()):
        if set(pair)!={'analytical','direct'}:
            raise SystemExit(f'incomplete pair n={n} rep={rep}')
        a,d=pair['analytical'],pair['direct']
        for key in diag:
            if a[key]!=d[key]:
                raise SystemExit(f'diagnostic drift n={n} rep={rep} key={key}: {a[key]} != {d[key]}')
        if a['MAX_MASS_RESIDUAL']!=d['MAX_MASS_RESIDUAL']:
            raise SystemExit(f'mass residual drift n={n} rep={rep}')
        av=float(a['NS_PER_COLUMN']); dv=float(d['NS_PER_COLUMN'])
        ratios.append(dv/av); ans.append(av); dirs.append(dv)
    print(f'PROFILE04_AHL_APP_N={n}|ANALYTICAL_MEDIAN_NS={statistics.median(ans):.6f}|DIRECT_MEDIAN_NS={statistics.median(dirs):.6f}|PAIRED_MEAN_RATIO={statistics.mean(ratios):.9f}|PAIRED_MEDIAN_RATIO={statistics.median(ratios):.9f}|PAIRS={len(ratios)}')
    print(f'PROFILE04_AHL_APP_SPEEDUP_N={n}|MEAN_PERCENT={(1-statistics.mean(ratios))*100:.6f}|MEDIAN_PERCENT={(1-statistics.median(ratios))*100:.6f}')
print('FPE_PROFILE04_AHL_APPLICATION_RUNTIME=PASS')
PY
