#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx03-t1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "APPROX03_T2_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys

src=Path("tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90").read_text()
src=src.replace(
    "use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE",
    "use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE",1)
src=src.replace(
    "  real(real64), parameter :: h0 = -75.0_real64",
    "  real(real64) :: h0 = -75.0_real64",1)
src=src.replace(
    "  real(real64), parameter :: upward_dt = 1.0e-4_real64",
    "  real(real64) :: upward_dt = 1.0e-2_real64",1)
src=src.replace(
    "  real(real64), parameter :: qualification_head_budget = 2.5e-11_real64",
    "  real(real64) :: qualification_head_budget = 1.0e-5_real64",1)
src=src.replace(
    "  real(real64) :: k0, qeq\n",
    "  real(real64) :: k0, qeq, t2_top_flux, t2_predictor_qbot, t2_bottom_head, t2_top_factor, t2_qbot_factor\n"
    "  real(real64) :: t2_heads(numnod)=0.0_real64, t2_water(numnod)=0.0_real64\n"
    "  character(len=64) :: arg\n"
    "  character(len=8) :: t2_material\n",1)

old_cof="""    parameters%cofgen = 0.0_real64
    do k = 1, numnod
      parameters%cofgen(1,k)=0.032_real64; parameters%cofgen(2,k)=0.423_real64; parameters%cofgen(3,k)=4.75_real64
      parameters%cofgen(4,k)=0.0135_real64; parameters%cofgen(5,k)=0.365_real64; parameters%cofgen(6,k)=1.455_real64
      parameters%cofgen(7,k)=1.0_real64-1.0_real64/parameters%cofgen(6,k); parameters%cofgen(8,k)=parameters%cofgen(4,k)
      parameters%cofgen(9,k)=0.0_real64; parameters%cofgen(10,k)=parameters%cofgen(3,k); parameters%cofgen(11,k)=0.999_real64
      parameters%cofgen(12,k)=0.99_real64*parameters%cofgen(3,k); parameters%cofgen(22,k)=-1.0e6_real64
      parameters%cofgen(23,k)=1.0e-12_real64
    end do
"""
new_cof="""    block
      real(real64) :: tr,ts,alpha,nvg,ksat,lambda
      call material_parameters(trim(t2_material),tr,ts,alpha,nvg,ksat,lambda)
      parameters%cofgen = 0.0_real64
      do k = 1, numnod
        parameters%cofgen(1,k)=tr; parameters%cofgen(2,k)=ts; parameters%cofgen(3,k)=ksat
        parameters%cofgen(4,k)=alpha; parameters%cofgen(5,k)=lambda; parameters%cofgen(6,k)=nvg
        parameters%cofgen(7,k)=1.0_real64-1.0_real64/nvg; parameters%cofgen(8,k)=alpha
        parameters%cofgen(9,k)=0.0_real64; parameters%cofgen(10,k)=ksat; parameters%cofgen(11,k)=0.999_real64
        parameters%cofgen(12,k)=0.99_real64*ksat; parameters%cofgen(22,k)=-1.0e6_real64
        parameters%cofgen(23,k)=1.0e-12_real64
      end do
    end block
"""
if old_cof not in src: raise SystemExit("cofgen seam missing")
src=src.replace(old_cof,new_cof,1)

start=src.index("  call determine_initial_conductivity(k0)")
end=src.index("\ncontains\n",start)
main="""  if(command_argument_count()/=6) error stop 'usage: MATERIAL H0 TOP_FACTOR QBOT_FACTOR DT_DAY BUDGET_CM'
  call get_command_argument(1,t2_material)
  call get_command_argument(2,arg); read(arg,*) h0
  call get_command_argument(3,arg); read(arg,*) t2_top_factor
  call get_command_argument(4,arg); read(arg,*) t2_qbot_factor
  call get_command_argument(5,arg); read(arg,*) upward_dt
  call get_command_argument(6,arg); read(arg,*) qualification_head_budget
  if(upward_dt<=0.0_real64 .or. qualification_head_budget<=0.0_real64) error stop 'invalid controls'
  call prepare_t2_controls()
  call run_t2_point()
"""
src=src[:start]+main+src[end:]

insert="""\n  subroutine material_parameters(name,tr,ts,alpha,nvg,ksat,lambda)
    character(len=*),intent(in)::name
    real(real64),intent(out)::tr,ts,alpha,nvg,ksat,lambda
    select case(trim(name))
    case('B01')
      tr=0.02_real64; ts=0.427494_real64; alpha=0.021659_real64; nvg=1.734737_real64
      ksat=31.225016_real64; lambda=0.98087_real64
    case('B12')
      tr=0.01_real64; ts=0.529749_real64; alpha=0.016562_real64; nvg=1.090671_real64
      ksat=2.245895_real64; lambda=-4.493581_real64
    case('O05')
      tr=0.01_real64; ts=0.336701_real64; alpha=0.030304_real64; nvg=2.887502_real64
      ksat=17.418504_real64; lambda=0.0736_real64
    case('O14')
      tr=0.01_real64; ts=0.393878_real64; alpha=0.003288_real64; nvg=1.616573_real64
      ksat=2.495984_real64; lambda=0.514012_real64
    case default
      error stop 'unknown material'
    end select
  end subroutine material_parameters

  subroutine prepare_t2_controls()
    type(fmr_b110_physical_parameters_t) :: parameters
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer::i
    call initialize_parameters(parameters,5)
    heads(1)=h0
    do i=2,numnod
      heads(i)=heads(i-1)+parameters%node_distance(i)
    end do
    call initialize_b110_default_mvg_parameters(hp,parameters%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,upward_dt)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    if(conductivity(1)<=0.0_real64 .or. conductivity(numnod)<=0.0_real64) error stop 'invalid local conductivity'
    t2_top_flux=t2_top_factor*conductivity(1)
    t2_predictor_qbot=t2_qbot_factor*conductivity(numnod)
    t2_bottom_head=heads(numnod)+0.5_real64*parameters%dz(numnod)* &
         (1.0_real64+t2_predictor_qbot/conductivity(numnod))
  end subroutine prepare_t2_controls

  subroutine run_t2_point()
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    real(real64) :: clock0,clock1
    call cpu_time(clock0)
    call execute_case(5,t2_top_flux,0.0_real64,t2_bottom_head,upward_dt,.true.,.true.,output,observation)
    call cpu_time(clock1)
    write(*,'(*(g0))') 'APPROX03_T2C_MATRIX_RAW|MATERIAL=',trim(t2_material),'|H0=',h0, &
         '|TOP_FACTOR=',t2_top_factor,'|QBOT_FACTOR=',t2_qbot_factor,'|TOP=',t2_top_flux, &
         '|PRED_QBOT=',t2_predictor_qbot,'|HBOT=',t2_bottom_head,'|DT=',upward_dt, &
         '|BUDGET=',qualification_head_budget,'|SECONDS=',clock1-clock0,'|COMPLETED=',output%completed, &
         '|COMMITTED=',output%committed,'|KERNEL_STATUS=',output%kernel_status,'|SUBSTEPS=',output%accepted_substeps, &
         '|RETRIES=',output%solver_internal_retries,'|NONLINEAR=',output%solver_nonlinear_iterations, &
         '|HEADCALC=',output%solver_headcalc_calls,'|MASS_COMPLETE=',output%mass%complete,'|MASS_RESIDUAL=',output%mass%residual, &
         '|STORAGE_START=',output%mass%storage_start,'|STORAGE_END=',output%mass%storage_end, &
         '|STORAGE_CHANGE=',output%mass%storage_change,'|TOTAL_IN=',output%mass%total_in,'|TOTAL_OUT=',output%mass%total_out, &
         '|BOTTOM_FLUX=',observation%bottom_flux,'|BINF=',observation%temporal_head_inf_bound,'|CH=',observation%temporal_normalized_indicator, &
         '|H1=',t2_heads(1),'|H2=',t2_heads(2),'|H3=',t2_heads(3),'|H4=',t2_heads(4), &
         '|TH1=',t2_water(1),'|TH2=',t2_water(2),'|TH3=',t2_water(3),'|TH4=',t2_water(4)
  end subroutine run_t2_point
"""
src=src.replace("\ncontains\n","\ncontains\n"+insert,1)

old_decl="""    integer :: active_physical_calls
    logical :: ok
"""
new_decl="""    integer :: active_physical_calls
    logical :: ok, snapshot_available
    class(transaction_state_t), allocatable :: snapshot
"""
if old_decl not in src: raise SystemExit("execute declaration seam missing")
src=src.replace(old_decl,new_decl,1)

old_tail="""    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, 0.0_real64, duration, output, diagnostic, runtime, active_physical_calls)
    observation = backend%observation()
"""
new_tail="""    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, 0.0_real64, duration, output, diagnostic, runtime, active_physical_calls)
    observation = backend%observation()
    t2_heads=0.0_real64; t2_water=0.0_real64
    if(output%committed) then
      call committed%snapshot(snapshot,snapshot_available)
      if(snapshot_available .and. allocated(snapshot)) then
        select type(state=>snapshot)
        class is(fmr_b110_physical_state_t)
          if(allocated(state%pressure_head) .and. allocated(state%water_content)) then
            t2_heads=state%pressure_head
            t2_water=state%water_content
          end if
        class default
          continue
        end select
      end if
    end if
"""
if old_tail not in src: raise SystemExit("execute tail seam missing")
src=src.replace(old_tail,new_tail,1)
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

materials=(B01 B12 O05 O14)
regimes=("wet|-10" "mid|-75" "dry|-500")
orientations=("plus|5e-5|5e-5" "minus|-5e-5|-5e-5")
budgets=(1e-5 1.25e-5)
labels=(REF T2C)
reps=5
summary="$BUILD/matrix.txt"
: > "$summary"

for material in "${materials[@]}"; do
  for regime_spec in "${regimes[@]}"; do
    IFS='|' read -r regime h0 <<< "$regime_spec"
    for orient_spec in "${orientations[@]}"; do
      IFS='|' read -r orientation top_factor qbot_factor <<< "$orient_spec"
      for i in "${!budgets[@]}"; do
        budget="${budgets[$i]}"
        arm="${labels[$i]}"
        times="$BUILD/times-${material}-${regime}-${orientation}-${arm}.txt"
        : > "$times"
        last=""
        for ((rep=1; rep<=reps; rep++)); do
          raw="$("$BUILD/test" "$material" "$h0" "$top_factor" "$qbot_factor" 1e-4 "$budget" 2>&1)" || {
            printf '%s\n' "$raw" >&2
            fail "$material $regime $orientation $arm execution"
          }
          line="$(printf '%s\n' "$raw" | grep '^APPROX03_T2C_MATRIX_RAW|' | tail -1 || true)"
          [[ -n "$line" ]] || fail "$material $regime $orientation $arm missing result"
          committed="$(printf '%s\n' "$line" | sed -n 's/.*|COMMITTED=\([^|]*\).*/\1/p')"
          mass_complete="$(printf '%s\n' "$line" | sed -n 's/.*|MASS_COMPLETE=\([^|]*\).*/\1/p')"
          [[ "$committed" == "T" && "$mass_complete" == "T" ]] || fail "$material $regime $orientation $arm not committed/mass-complete"
          seconds="$(printf '%s\n' "$line" | sed -n 's/.*|SECONDS=\([^|]*\).*/\1/p')"
          printf '%s\n' "$seconds" >> "$times"
          last="$line"
        done
        median="$(python3 - "$times" <<'PY'
import statistics,sys
v=[float(x) for x in open(sys.argv[1]) if x.strip()]
print(f"{statistics.median(v):.17e}")
PY
)"
        printf 'MATERIAL=%s|REGIME=%s|ORIENTATION=%s|ARM=%s|MEDIAN_SECONDS=%s|%s\n'           "$material" "$regime" "$orientation" "$arm" "$median" "${last#APPROX03_T2C_MATRIX_RAW|}" >> "$summary"
      done
    done
  done
done

python3 - "$summary" <<'PY'
import math,statistics,sys
rows={}
for line in open(sys.argv[1]):
    d={}
    for p in line.strip().split("|"):
        if "=" in p:
            k,v=p.split("=",1); d[k]=v
    rows[(d["MATERIAL"],d["REGIME"],d["ORIENTATION"],d["ARM"])]=d

def f(d,k): return float(d[k])
def ii(d,k): return int(d[k])
def rel(a,b): return abs(a-b)/max(abs(a),1e-30)

speedups=[]; work_reduced=0; signed_flux_errors=[]
metrics={"head":0.0,"theta":0.0,"flux":0.0,"storage_change":0.0,"storage_end":0.0}
for material in ("B01","B12","O05","O14"):
  for regime in ("wet","mid","dry"):
    for orientation in ("plus","minus"):
      ref=rows[(material,regime,orientation,"REF")]
      cand=rows[(material,regime,orientation,"T2C")]
      rh=[f(ref,f"H{i}") for i in range(1,5)]
      ch=[f(cand,f"H{i}") for i in range(1,5)]
      rt=[f(ref,f"TH{i}") for i in range(1,5)]
      ct=[f(cand,f"TH{i}") for i in range(1,5)]
      head_rel=max(rel(a,b) for a,b in zip(rh,ch))
      theta_rel=max(rel(a,b) for a,b in zip(rt,ct))
      flux_rel=rel(f(ref,"BOTTOM_FLUX"),f(cand,"BOTTOM_FLUX"))
      sch_rel=rel(f(ref,"STORAGE_CHANGE"),f(cand,"STORAGE_CHANGE"))
      send_rel=rel(f(ref,"STORAGE_END"),f(cand,"STORAGE_END"))
      speed=100.0*(1.0-f(cand,"MEDIAN_SECONDS")/f(ref,"MEDIAN_SECONDS"))
      speedups.append(speed)
      if ii(cand,"SUBSTEPS") < ii(ref,"SUBSTEPS") or ii(cand,"NONLINEAR") < ii(ref,"NONLINEAR"):
          work_reduced += 1
      signed_flux_errors.append(f(cand,"BOTTOM_FLUX")-f(ref,"BOTTOM_FLUX"))
      metrics["head"]=max(metrics["head"],head_rel)
      metrics["theta"]=max(metrics["theta"],theta_rel)
      metrics["flux"]=max(metrics["flux"],flux_rel)
      metrics["storage_change"]=max(metrics["storage_change"],sch_rel)
      metrics["storage_end"]=max(metrics["storage_end"],send_rel)
      if abs(f(cand,"MASS_RESIDUAL")) > 1e-12:
          raise SystemExit("candidate mass residual gate")
      print(
        f"APPROX03_T2C_CASE|MATERIAL={material}|REGIME={regime}|ORIENTATION={orientation}"
        f"|SPEEDUP_PERCENT={speed:.6f}|REF_SUBSTEPS={ii(ref,'SUBSTEPS')}|T2C_SUBSTEPS={ii(cand,'SUBSTEPS')}"
        f"|REF_NONLINEAR={ii(ref,'NONLINEAR')}|T2C_NONLINEAR={ii(cand,'NONLINEAR')}"
        f"|REF_HEADCALC={ii(ref,'HEADCALC')}|T2C_HEADCALC={ii(cand,'HEADCALC')}"
        f"|HEAD_REL={head_rel:.17e}|THETA_REL={theta_rel:.17e}|BOTTOM_FLUX_REL={flux_rel:.17e}"
        f"|BOTTOM_FLUX_SIGNED_ERROR={signed_flux_errors[-1]:.17e}|STORAGE_CHANGE_REL={sch_rel:.17e}"
        f"|STORAGE_END_REL={send_rel:.17e}|MASS_RESIDUAL={f(cand,'MASS_RESIDUAL'):.17e}"
      )

pos=sum(x>0 for x in speedups)
neg=sum(x<0 for x in speedups)
print(
  f"APPROX03_T2C_SUMMARY|CASES={len(speedups)}|WORK_REDUCED={work_reduced}"
  f"|SPEED_POSITIVE={pos}|SPEED_NEGATIVE={neg}"
  f"|MEDIAN_SPEEDUP_PERCENT={statistics.median(speedups):.6f}|MIN_SPEEDUP_PERCENT={min(speedups):.6f}"
  f"|MAX_HEAD_REL={metrics['head']:.17e}|MAX_THETA_REL={metrics['theta']:.17e}"
  f"|MAX_BOTTOM_FLUX_REL={metrics['flux']:.17e}|MAX_STORAGE_CHANGE_REL={metrics['storage_change']:.17e}"
  f"|MAX_STORAGE_END_REL={metrics['storage_end']:.17e}"
  f"|MEAN_SIGNED_BOTTOM_FLUX_ERROR={statistics.mean(signed_flux_errors):.17e}"
)
print("FPE_APPROX03_T2C_MATRIX=PASS")
PY
