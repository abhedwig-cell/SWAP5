#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx03-temporal-discovery-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX03_TEMPORAL_DISCOVERY_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fpe/test_fpe_approx02_r1_transaction.f90").read_text()
src=src.replace("real(real64), parameter :: duration=1.0e-3_real64",
                "real(real64) :: duration=1.0e-3_real64",1)
src=src.replace("real(real64), parameter :: r1_tol=1.0e-2_real64",
                "real(real64), parameter :: r1_tol=exact_tol",1)
src=src.replace(
    "  if(command_argument_count()/=3) error stop 'usage: MATERIAL REGIME H0_CM'\n"
    "  call get_command_argument(1,material)\n"
    "  call get_command_argument(2,regime)\n"
    "  call get_command_argument(3,arg); read(arg,*) h0\n",
    "  if(command_argument_count()/=4) error stop 'usage: MATERIAL REGIME H0_CM DURATION_DAY'\n"
    "  call get_command_argument(1,material)\n"
    "  call get_command_argument(2,regime)\n"
    "  call get_command_argument(3,arg); read(arg,*) h0\n"
    "  call get_command_argument(4,arg); read(arg,*) duration\n"
    "  if(duration<=0.0_real64) error stop 'duration must be positive'\n",1)
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
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$BUILD/test.f90" -o "$BUILD/test.o" || fail "compile fixture"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link"

CSV="$BUILD/results.csv"
echo 'material,regime,h0,duration,completed,steps,substeps,retries,nonlinear,backtrack,mass_rejections,max_mass_residual,rc' > "$CSV"

durations=(1e-5 2.5e-5 5e-5 1e-4 2.5e-4 5e-4 7.5e-4 1e-3)

run_case(){
  local material="$1" regime="$2" h0="$3" duration="$4" raw rc line
  set +e
  raw="$("$BUILD/test" "$material" "$regime" "$h0" "$duration" 2>&1)"
  rc=$?
  set -e
  line="$(printf '%s\n' "$raw" | grep '^APPROX02_R1_TRANSACTION|' | tail -1 || true)"
  if [[ -z "$line" ]]; then
    echo "APPROX03_TEMPORAL_NO_RECORD|MATERIAL=$material|REGIME=$regime|DURATION=$duration|RC=$rc"
    return
  fi
  python3 - "$material" "$regime" "$h0" "$duration" "$rc" "$line" "$CSV" <<'PY'
import csv,sys
material,regime,h0,duration,rc,line,path=sys.argv[1:]
d={}
for part in line.strip().split('|')[1:]:
    if '=' in part:
        k,v=part.split('=',1); d[k]=v
completed=d['EXACT_COMPLETED'].strip().lower() in ('t','true','.true.')
row=[material,regime,h0,duration,int(completed),d['EXACT_STEPS'],d['EXACT_ACCEPTED_SUBSTEPS'],
     d['EXACT_RETRIES'],d['EXACT_NONLINEAR'],d['EXACT_BACKTRACK'],d['EXACT_MASS_REJECTIONS'],
     d['EXACT_MAX_MASS_RESIDUAL'],rc]
with open(path,'a',newline='') as f:
    csv.writer(f).writerow(row)
print(
  f"APPROX03_TEMPORAL_DISCOVERY|MATERIAL={material}|REGIME={regime}|DURATION={duration}"
  f"|COMPLETED={int(completed)}|STEPS={d['EXACT_STEPS']}|ACCEPTED_SUBSTEPS={d['EXACT_ACCEPTED_SUBSTEPS']}"
  f"|RETRIES={d['EXACT_RETRIES']}|NONLINEAR={d['EXACT_NONLINEAR']}|BACKTRACK={d['EXACT_BACKTRACK']}"
  f"|MASS_REJECTIONS={d['EXACT_MASS_REJECTIONS']}|MAX_MASS_RESIDUAL={d['EXACT_MAX_MASS_RESIDUAL']}|RC={rc}"
)
PY
}

for material in B01 B12 O05 O14; do
  for spec in "wet -10" "mid -75" "dry -500"; do
    read -r regime h0 <<< "$spec"
    for duration in "${durations[@]}"; do
      run_case "$material" "$regime" "$h0" "$duration"
    done
  done
done

python3 - "$CSV" <<'PY'
import csv,sys
rows=list(csv.DictReader(open(sys.argv[1])))
if not rows:
    raise SystemExit('no discovery rows')
completed=[r for r in rows if int(r['completed'])==1]
stress=[r for r in completed if int(r['substeps'])>8 or int(r['retries'])>0]
print(f"APPROX03_TEMPORAL_SUMMARY|ROWS={len(rows)}|COMPLETED={len(completed)}|REFINED={len(stress)}")
failed=[r for r in rows if int(r['completed'])==0]
if failed:
    f=max(failed,key=lambda r:(int(r['retries']),int(r['nonlinear'])))
    print(
      f"APPROX03_TEMPORAL_FAILED_EDGE|MATERIAL={f['material']}|REGIME={f['regime']}|DURATION={f['duration']}"
      f"|RETRIES={f['retries']}|NONLINEAR={f['nonlinear']}|BACKTRACK={f['backtrack']}"
    )
if not stress:
    raise SystemExit('no converged temporal-refinement workload found')
stress.sort(key=lambda r:(int(r['substeps']),int(r['retries']),int(r['nonlinear'])),reverse=True)
for r in stress[:24]:
    print(
      f"APPROX03_TEMPORAL_REFINED|MATERIAL={r['material']}|REGIME={r['regime']}|H0={r['h0']}|DURATION={r['duration']}"
      f"|ACCEPTED_SUBSTEPS={r['substeps']}|RETRIES={r['retries']}|NONLINEAR={r['nonlinear']}|BACKTRACK={r['backtrack']}"
    )
best=stress[0]
print(
  f"APPROX03_TEMPORAL_SELECTED|MATERIAL={best['material']}|REGIME={best['regime']}|H0={best['h0']}|DURATION={best['duration']}"
  f"|ACCEPTED_SUBSTEPS={best['substeps']}|RETRIES={best['retries']}|NONLINEAR={best['nonlinear']}"
)
print('FPE_APPROX03_TEMPORAL_DISCOVERY=PASS')
PY
