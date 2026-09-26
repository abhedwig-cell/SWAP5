#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx03-certificate-discovery-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX03_CERTIFICATE_DISCOVERY_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys,re
src=Path("tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90").read_text()

src=src.replace(
    "  real(real64), parameter :: upward_dt = 1.0e-4_real64",
    "  real(real64) :: upward_dt = 1.0e-4_real64",1)
src=src.replace(
    "  real(real64), parameter :: qualification_head_budget = 2.5e-11_real64",
    "  real(real64) :: qualification_head_budget = 2.5e-11_real64",1)

src=src.replace(
    "  real(real64) :: k0, qeq\n",
    "  real(real64) :: k0, qeq, q_probe\n  character(len=64) :: arg\n",1)

start=src.index("  call determine_initial_conductivity(k0)")
end=src.index("\ncontains\n",start)
main="""  if(command_argument_count()/=3) error stop 'usage: Q_CM_PER_DAY DT_DAY BUDGET_CM'
  call get_command_argument(1,arg); read(arg,*) q_probe
  call get_command_argument(2,arg); read(arg,*) upward_dt
  call get_command_argument(3,arg); read(arg,*) qualification_head_budget
  if(upward_dt<=0.0_real64 .or. qualification_head_budget<=0.0_real64) error stop 'invalid discovery controls'
  call determine_initial_conductivity(k0)
  qeq=-k0
  call verify_positive_bottom_inflow(q_probe)
  write(*,'(A)') 'FPE_APPROX03_CERTIFICATE_POINT=PASS'
"""
src=src[:start]+main+src[end:]

needle="""    call execute_case(2, q, q, 777777.0_real64, upward_dt, .true., .true., output, observation)
"""
insert=needle+"""    write(*,'(*(g0))') 'APPROX03_CERTIFICATE|Q=',q,'|DT=',upward_dt,'|BUDGET=',qualification_head_budget, &
         '|COMPLETED=',output%completed,'|COMMITTED=',output%committed,'|KERNEL_STATUS=',output%kernel_status, &
         '|ACCEPTED_SUBSTEPS=',output%accepted_substeps,'|INTERNAL_RETRIES=',output%solver_internal_retries, &
         '|NONLINEAR=',output%solver_nonlinear_iterations,'|HEADCALC=',output%solver_headcalc_calls, &
         '|MASS_RESIDUAL=',output%mass%residual,'|CERT_AVAILABLE=',observation%temporal_certificate_available, &
         '|BINF=',observation%temporal_head_inf_bound,'|CH=',observation%temporal_normalized_indicator
"""
if needle not in src: raise SystemExit("execute seam missing")
src=src.replace(needle,insert,1)

old="""    call require(output%completed .and. output%committed, 'positive qbot transaction committed')
"""
if old not in src: raise SystemExit("commit require seam missing")
src=src.replace(old,"    if(.not.output%completed .or. .not.output%committed) return\n",1)

src=src.replace("    call require(output%accepted_substeps == 1, 'positive qbot accepted without retry subdivision')\n","",1)
src=src.replace("    call require(output%solver_headcalc_calls == 1, 'positive qbot one principal HeadCalc trajectory')\n","",1)

start_oracle=src.find("    scale = max(1.0_real64,abs(expected_upward_binf),abs(observation%temporal_head_inf_bound))")
end_oracle=src.find("    call require(ieee_is_finite(observation%temporal_normalized_indicator)",start_oracle)
if start_oracle<0 or end_oracle<0:
    raise SystemExit("expected Binf oracle seam missing")
src=src[:start_oracle]+src[end_oracle:]

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
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
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
echo 'q,dt,budget,completed,committed,status,substeps,retries,nonlinear,headcalc,mass_residual,cert_available,binf,ch' > "$CSV"

qs=(1e-10 2.5e-10 5e-10 1e-9 2.5e-9 5e-9 1e-8 2.5e-8 5e-8 1e-7)
dts=(1e-4 2.5e-4 5e-4 1e-3 2.5e-3 5e-3 1e-2)
budget=2.5e-11

for q in "${qs[@]}"; do
  for dt in "${dts[@]}"; do
    raw="$("$BUILD/test" "$q" "$dt" "$budget" 2>&1)" || { printf '%s\n' "$raw" >&2; fail "point q=$q dt=$dt"; }
    line="$(printf '%s\n' "$raw" | grep '^APPROX03_CERTIFICATE|' | tail -1)"
    python3 - "$line" "$CSV" <<'PY'
import csv,sys
line,path=sys.argv[1:]
d={}
for part in line.strip().split('|')[1:]:
    if '=' in part:
        k,v=part.split('=',1); d[k]=v
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([
      d['Q'],d['DT'],d['BUDGET'],d['COMPLETED'],d['COMMITTED'],d['KERNEL_STATUS'],
      d['ACCEPTED_SUBSTEPS'],d['INTERNAL_RETRIES'],d['NONLINEAR'],d['HEADCALC'],
      d['MASS_RESIDUAL'],d['CERT_AVAILABLE'],d['BINF'],d['CH']
    ])
print(line)
PY
  done
done

python3 - "$CSV" <<'PY'
import csv,sys
rows=list(csv.DictReader(open(sys.argv[1])))
def truth(v): return v.strip().lower() in ('t','true','.true.','1')
committed=[r for r in rows if truth(r['completed']) and truth(r['committed'])]
refined=[r for r in committed if int(r['substeps'])>1 or int(r['retries'])>0]
failed=[r for r in rows if not (truth(r['completed']) and truth(r['committed']))]
print(f"APPROX03_CERTIFICATE_SUMMARY|ROWS={len(rows)}|COMMITTED={len(committed)}|REFINED={len(refined)}|FAILED={len(failed)}")
if not refined:
    if committed:
        edge=max(committed,key=lambda r:float(r['ch']) if r['ch'] not in ('','NaN') else -1)
        print(f"APPROX03_CERTIFICATE_NEAREST|Q={edge['q']}|DT={edge['dt']}|SUBSTEPS={edge['substeps']}|RETRIES={edge['retries']}|BINF={edge['binf']}|CH={edge['ch']}")
    raise SystemExit('no committed model-certificate refinement workload found')
refined.sort(key=lambda r:(int(r['substeps']),int(r['retries']),int(r['nonlinear'])),reverse=True)
for r in refined[:20]:
    print(
      f"APPROX03_CERTIFICATE_REFINED|Q={r['q']}|DT={r['dt']}|SUBSTEPS={r['substeps']}|RETRIES={r['retries']}"
      f"|NONLINEAR={r['nonlinear']}|HEADCALC={r['headcalc']}|BINF={r['binf']}|CH={r['ch']}|MASS_RESIDUAL={r['mass_residual']}"
    )
best=refined[0]
print(
  f"APPROX03_CERTIFICATE_SELECTED|Q={best['q']}|DT={best['dt']}|SUBSTEPS={best['substeps']}|RETRIES={best['retries']}"
  f"|NONLINEAR={best['nonlinear']}|BINF={best['binf']}|CH={best['ch']}"
)
print('FPE_APPROX03_CERTIFICATE_DISCOVERY=PASS')
PY
