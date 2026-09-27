#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx03-t1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX03_T1_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys

src=Path("tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90").read_text()

src=src.replace(
    "use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE",
    "use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE",1)
src=src.replace(
    "  real(real64), parameter :: upward_dt = 1.0e-4_real64",
    "  real(real64) :: upward_dt = 1.0e-2_real64",1)
src=src.replace(
    "  real(real64), parameter :: qualification_head_budget = 2.5e-11_real64",
    "  real(real64) :: qualification_head_budget = 2.5e-11_real64",1)
src=src.replace(
    "  real(real64) :: k0, qeq\n",
    "  real(real64) :: k0, qeq, q_probe\n"
    "  real(real64) :: t1_seconds=0.0_real64, t1_storage_end=0.0_real64, t1_bottom_exchange=0.0_real64\n"
    "  real(real64) :: t1_heads(numnod)=0.0_real64, t1_water(numnod)=0.0_real64\n"
    "  integer :: t1_substeps=0,t1_retries=0,t1_nonlinear=0,t1_headcalc=0\n"
    "  character(len=64) :: arg\n",1)

start=src.index("  call determine_initial_conductivity(k0)")
end=src.index("\ncontains\n",start)
main="""  if(command_argument_count()/=3) error stop 'usage: Q_CM_PER_DAY DT_DAY BUDGET_CM'
  call get_command_argument(1,arg); read(arg,*) q_probe
  call get_command_argument(2,arg); read(arg,*) upward_dt
  call get_command_argument(3,arg); read(arg,*) qualification_head_budget
  if(upward_dt<=0.0_real64 .or. qualification_head_budget<=0.0_real64) error stop 'invalid controls'
  call determine_initial_conductivity(k0)
  qeq=-k0
  call verify_positive_bottom_inflow(q_probe)
  write(*,'(*(g0))') 'APPROX03_T1_POINT|Q=',q_probe,'|DT=',upward_dt,'|BUDGET=',qualification_head_budget, &
       '|SECONDS=',t1_seconds,'|SUBSTEPS=',t1_substeps,'|RETRIES=',t1_retries,'|NONLINEAR=',t1_nonlinear, &
       '|HEADCALC=',t1_headcalc,'|STORAGE_END=',t1_storage_end,'|BOTTOM_EXCHANGE=',t1_bottom_exchange, &
       '|H1=',t1_heads(1),'|H2=',t1_heads(2),'|H3=',t1_heads(3),'|H4=',t1_heads(4), &
       '|TH1=',t1_water(1),'|TH2=',t1_water(2),'|TH3=',t1_water(3),'|TH4=',t1_water(4)
  write(*,'(A)') 'FPE_APPROX03_T1_POINT=PASS'
"""
src=src[:start]+main+src[end:]

needle="""    call execute_case(2, q, q, 777777.0_real64, upward_dt, .true., .true., output, observation)
"""
if needle not in src: raise SystemExit("positive qbot execute seam missing")
# keep call unchanged

# Remove fixed one-substep/headcalc and fixed Binf-oracle constraints.
src=src.replace("    call require(output%accepted_substeps == 1, 'positive qbot accepted without retry subdivision')\n","",1)
src=src.replace("    call require(output%solver_headcalc_calls == 1, 'positive qbot one principal HeadCalc trajectory')\n","",1)
start_oracle=src.find("    scale = max(1.0_real64,abs(expected_upward_binf),abs(observation%temporal_head_inf_bound))")
end_oracle=src.find("    call require(ieee_is_finite(observation%temporal_normalized_indicator)",start_oracle)
if start_oracle<0 or end_oracle<0:
    raise SystemExit("fixed Binf oracle seam missing")
src=src[:start_oracle]+src[end_oracle:]

# Capture timing and final committed state inside execute_case.
old_decl="""    integer :: active_physical_calls
    logical :: ok
"""
new_decl="""    integer :: active_physical_calls
    logical :: ok, snapshot_available
    real(real64) :: clock0, clock1
    class(transaction_state_t), allocatable :: snapshot
"""
if old_decl not in src: raise SystemExit("execute declarations seam missing")
src=src.replace(old_decl,new_decl,1)

old_call="""    call backend%initialize(top)
    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, 0.0_real64, duration, output, diagnostic, runtime, active_physical_calls)
    observation = backend%observation()
"""
new_call="""    call backend%initialize(top)
    call cpu_time(clock0)
    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, 0.0_real64, duration, output, diagnostic, runtime, active_physical_calls)
    call cpu_time(clock1)
    observation = backend%observation()
    if (use_certificate) then
      t1_seconds = clock1-clock0
      t1_substeps = output%accepted_substeps
      t1_retries = output%solver_internal_retries
      t1_nonlinear = output%solver_nonlinear_iterations
      t1_headcalc = output%solver_headcalc_calls
      if (output%mass%complete) then
        t1_storage_end = output%mass%storage_end
        t1_bottom_exchange = -observation%bottom_flux*duration
      end if
      if (output%committed) then
        call committed%snapshot(snapshot,snapshot_available)
        if (snapshot_available .and. allocated(snapshot)) then
          select type(state=>snapshot)
          type is(fmr_b110_physical_state_t)
            if (allocated(state%pressure_head) .and. allocated(state%water_content)) then
              t1_heads = state%pressure_head
              t1_water = state%water_content
            end if
          class default
            continue
          end select
        end if
      end if
    end if
"""
if old_call not in src: raise SystemExit("execute call seam missing")
src=src.replace(old_call,new_call,1)

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
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$BUILD/test.f90" -o "$BUILD/test.o" || fail "compile fixture"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link"

Q=5e-10
DT=1e-2
budgets=(2.5e-11 5e-11 1e-10 2e-10)
REPS=5
CSV="$BUILD/results.csv"
echo 'budget,rep,seconds,substeps,retries,nonlinear,headcalc,storage,bottom,h1,h2,h3,h4,th1,th2,th3,th4' > "$CSV"

for budget in "${budgets[@]}"; do
  for rep in $(seq 1 "$REPS"); do
    raw="$("$BUILD/test" "$Q" "$DT" "$budget" 2>&1)" || { printf '%s\n' "$raw" >&2; fail "budget=$budget rep=$rep"; }
    line="$(printf '%s\n' "$raw" | grep '^APPROX03_T1_POINT|' | tail -1)"
    python3 - "$budget" "$rep" "$line" "$CSV" <<'PY'
import csv,sys
budget,rep,line,path=sys.argv[1:]
d={}
for part in line.strip().split('|')[1:]:
    k,v=part.split('=',1); d[k]=v
keys=['SECONDS','SUBSTEPS','RETRIES','NONLINEAR','HEADCALC','STORAGE_END','BOTTOM_EXCHANGE',
      'H1','H2','H3','H4','TH1','TH2','TH3','TH4']
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([budget,rep]+[d[k] for k in keys])
print(line)
PY
  done
done

python3 - "$CSV" <<'PY'
import csv,statistics,sys,math
rows=list(csv.DictReader(open(sys.argv[1])))
budgets=[2.5e-11,5e-11,1e-10,2e-10]
groups={}
for b in budgets:
    groups[b]=[r for r in rows if math.isclose(float(r['budget']),b,rel_tol=0,abs_tol=b*1e-12)]
if any(len(v)!=5 for v in groups.values()):
    raise SystemExit({b:len(v) for b,v in groups.items()})
base=groups[budgets[0]]
# Deterministic physical reference from first exact replicate.
ref=base[0]
state_keys=['h1','h2','h3','h4','th1','th2','th3','th4']
for b in budgets:
    rr=groups[b]
    seconds=[float(r['seconds']) for r in rr]
    sub={int(r['substeps']) for r in rr}
    retries={int(r['retries']) for r in rr}
    nl={int(r['nonlinear']) for r in rr}
    hc={int(r['headcalc']) for r in rr}
    max_head=max(abs(float(r[k])-float(ref[k])) for r in rr for k in ('h1','h2','h3','h4'))
    max_theta=max(abs(float(r[k])-float(ref[k])) for r in rr for k in ('th1','th2','th3','th4'))
    max_storage=max(abs(float(r['storage'])-float(ref['storage'])) for r in rr)
    max_bottom=max(abs(float(r['bottom'])-float(ref['bottom'])) for r in rr)
    base_median=statistics.median(float(r['seconds']) for r in base)
    ratio=statistics.median(seconds)/base_median
    print(
      f"APPROX03_T1_RESULT|BUDGET={b:.17e}|MEDIAN_SECONDS={statistics.median(seconds):.17e}"
      f"|RATIO={ratio:.9f}|SPEEDUP_PERCENT={(1-ratio)*100:.6f}"
      f"|SUBSTEPS={sorted(sub)}|RETRIES={sorted(retries)}|NONLINEAR={sorted(nl)}|HEADCALC={sorted(hc)}"
      f"|MAX_HEAD_ABS_CM={max_head:.17e}|MAX_THETA_ABS={max_theta:.17e}"
      f"|MAX_STORAGE_ABS={max_storage:.17e}|MAX_BOTTOM_EXCHANGE_ABS={max_bottom:.17e}"
    )
print('FPE_APPROX03_T1_BUDGET_FRONTIER=PASS')
PY
