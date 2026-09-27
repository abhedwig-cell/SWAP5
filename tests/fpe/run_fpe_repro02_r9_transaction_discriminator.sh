#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-repro02-r9-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/lib" "$BUILD/py"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "REPRO02_R9_FAIL $*" >&2; exit 1; }

cp tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90 "$BUILD/lib/mod_fgc44_real_swap_c_bridge.f90"
python3 - "$BUILD/lib/mod_fgc44_real_swap_c_bridge.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
src=src.replace(
"  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &\n"
"       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider\n",
"  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &\n"
"       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity\n",1)

src=src.replace(
"  use mod_canonical_contracts, only: canonical_numerical_config_t\n",
"  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_forcing_t\n",1)
src=src.replace(
"  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &\n"
"       kernel_candidate_state_t, kernel_diagnostics_t\n",
"  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &\n"
"       kernel_candidate_state_t, kernel_diagnostics_t, kernel_reference_floor_result_t, &\n"
"       kernel_reference_floor_candidate_t\n",1)
src=src.replace(
"  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &\n"
"       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY\n",
"  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &\n"
"       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, FMR_NUMERICAL_CONTINUATION_NONE, &\n"
"       FMR_OPTIONAL_STATE_LAYOUT_BASE\n",1)

src=src.replace(
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &\n"
"       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state\n",
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &\n"
"       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &\n"
"       fmr_new_b110_temporal_indicator_committed_state, fmr_new_b110_committed_state\n",1)

src=src.replace(
"  use mod_canonical_contracts, only: canonical_numerical_config_t\n",
"  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_forcing_t\n",1)
src=src.replace(
"  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &\n"
"       kernel_candidate_state_t, kernel_diagnostics_t\n",
"  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &\n"
"       kernel_candidate_state_t, kernel_diagnostics_t, kernel_reference_floor_result_t, &\n"
"       kernel_reference_floor_candidate_t\n",1)
src=src.replace(
"  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &\n"
"       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY\n",
"  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &\n"
"       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, FMR_NUMERICAL_CONTINUATION_NONE, &\n"
"       FMR_OPTIONAL_STATE_LAYOUT_BASE\n",1)
src=src.replace(
"    p%max_iterations=16; p%max_backtracking=8; p%min_step_duration=1.0e-8_real64\n",
"    p%max_iterations=48; p%max_backtracking=16; p%min_step_duration=1.0e-10_real64\n",1)

# Make case hydraulics configurable before initialize.
src=src.replace("H0_CM","REPRO_H0_CM")
# Align the participant committed/origin profile with PROFILE06/P0: uniform h0,
# not the default FGC44 hydrostatic profile construction.
hydro="""    heads(1)=REPRO_H0_CM
    do i=2,numnod
      heads(i)=heads(i-1)+p%node_distance(i)
    end do
"""
if src.count(hydro)<2:
    raise SystemExit(f"expected two hydrostatic profile seams, got {src.count(hydro)}")
src=src.replace(hydro,"    heads=REPRO_H0_CM\n")
src=src.replace(
"  real(real64), parameter :: REPRO_H0_CM=-75.0_real64\n",
"  real(real64), save :: REPRO_H0_CM=-75.0_real64\n"
"  real(real64), save :: REPRO_TR=0.032_real64, REPRO_TS=0.423_real64, REPRO_KSAT=4.75_real64\n"
"  real(real64), save :: REPRO_ALPHA=0.0135_real64, REPRO_LAMBDA=0.365_real64, REPRO_NVG=1.455_real64\n",1)
old="""      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
"""
new="""      p%cofgen(1,k)=REPRO_TR; p%cofgen(2,k)=REPRO_TS; p%cofgen(3,k)=REPRO_KSAT
      p%cofgen(4,k)=REPRO_ALPHA; p%cofgen(5,k)=REPRO_LAMBDA; p%cofgen(6,k)=REPRO_NVG
"""
if old not in src: raise SystemExit("material seam missing")
src=src.replace(old,new,1)

src=src.replace(
"  public :: fgc44_predictor_run_diagnostics_c\n",
"  public :: fgc44_predictor_run_diagnostics_c\n"
"  public :: fgc44_approx04_configure_case_c, fgc44_approx04_p1b_state_c, fgc44_approx04_predictor_q_c\n"
"  public :: fgc44_repro02_observation_c, fgc44_repro02_floor_c\n",1)
needle="""contains\n\n"""
insert="""\ncontains\n\n  integer(c_int) function fgc44_repro02_floor_c(head_m,floor_status,sample_valid,physical_advances,nonlinear, &
       internal_retries,headcalc,jacobian,linear,backtrack,mass_complete,mass_residual,bottom_exchange,terminal_flux) &
       bind(C,name="fgc44_repro02_floor_c")
    real(c_double), value, intent(in) :: head_m
    integer(c_int), intent(out) :: floor_status,sample_valid,physical_advances,nonlinear,internal_retries
    integer(c_int), intent(out) :: headcalc,jacobian,linear,backtrack,mass_complete
    real(c_double), intent(out) :: mass_residual,bottom_exchange,terminal_flux
    class(canonical_forcing_t), allocatable :: forcing
    class(transaction_state_t), allocatable :: snapshot
    type(fmr_b110_physical_state_t) :: base
    type(kernel_committed_state_t) :: floor_committed
    type(fmr_serialized_reference_backend_t) :: floor_backend
    type(fmr_template_t) :: floor_template
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    integer :: forcing_status
    logical :: available,ok

    fgc44_repro02_floor_c=1_c_int
    floor_status=-1_c_int; sample_valid=0_c_int; physical_advances=0_c_int; nonlinear=0_c_int
    internal_retries=0_c_int; headcalc=0_c_int; jacobian=0_c_int; linear=0_c_int; backtrack=0_c_int
    mass_complete=0_c_int; mass_residual=0.0_c_double; bottom_exchange=0.0_c_double; terminal_flux=0.0_c_double
    if(.not.initialized)return
    call materializer%materialize(real(head_m,real64),datum,forcing,forcing_status)
    if(forcing_status/=0 .or. .not.allocated(forcing))return
    call committed%snapshot(snapshot,available)
    if(.not.available .or. .not.allocated(snapshot))return
    select type(p=>snapshot)
    class is(fmr_b110_physical_state_t)
      base%active_nodes=p%active_nodes
      allocate(base%pressure_head(p%active_nodes),base%water_content(p%active_nodes))
      base%pressure_head=p%pressure_head; base%water_content=p%water_content
      base%ponding_depth=p%ponding_depth; base%groundwater_level=p%groundwater_level
    class default
      return
    end select
    call fmr_new_b110_committed_state(floor_committed,COLUMN_ID,base,window%t0,ok)
    if(.not.ok)return
    floor_template=template
    floor_template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    floor_template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    call floor_backend%initialize(top)
    select type(tf=>forcing)
    type is(fmr_b110_physical_forcing_t)
      call floor_backend%run_reference_floor_sample(column,floor_template,corrector_parameters,floor_committed,tf, &
           window%t0,window%t1,1.0e-12_real64,result,candidate,diagnostics)
    class default
      return
    end select
    floor_status=int(result%status,c_int)
    sample_valid=merge(1_c_int,0_c_int,result%sample_valid)
    physical_advances=int(result%physical_advances,c_int)
    nonlinear=int(result%nonlinear_iterations,c_int); internal_retries=int(result%internal_retries,c_int)
    headcalc=int(result%headcalc_calls,c_int); jacobian=int(result%jacobian_builds,c_int)
    linear=int(result%linear_solves,c_int); backtrack=int(result%backtracking_attempts,c_int)
    mass_complete=merge(1_c_int,0_c_int,result%mass%complete)
    mass_residual=real(result%mass%residual,c_double)
    bottom_exchange=real(result%bottom_outward_exchange_native,c_double)
    terminal_flux=real(result%terminal_bottom_outward_flux_native,c_double)
    fgc44_repro02_floor_c=0_c_int
  end function fgc44_repro02_floor_c

  integer(c_int) function fgc44_repro02_observation_c(solver_executed,solver_status,nonlinear,jacobian,linear, &
       backtrack,retries,constitutive,eq_available,temporal_enabled,temporal_status,temporal_available,certificate_available, &
       budget_supplied,budget_valid,eq_residual,head_bound,budget,normalized,top_flux,bottom_flux) &
       bind(C,name="fgc44_repro02_observation_c")
    integer(c_int), intent(out) :: solver_executed,solver_status,nonlinear,jacobian,linear,backtrack,retries,constitutive
    integer(c_int), intent(out) :: eq_available,temporal_enabled,temporal_status,temporal_available,certificate_available
    integer(c_int), intent(out) :: budget_supplied,budget_valid
    real(c_double), intent(out) :: eq_residual,head_bound,budget,normalized,top_flux,bottom_flux
    type(fmr_serialized_physical_observation_t) :: obs
    obs=corrector_backend%observation()
    solver_executed=merge(1_c_int,0_c_int,obs%solver_executed)
    solver_status=int(obs%solver_status,c_int)
    nonlinear=int(obs%solver_diagnostics%nonlinear_iterations,c_int)
    jacobian=int(obs%solver_diagnostics%jacobian_builds,c_int)
    linear=int(obs%solver_diagnostics%linear_solves,c_int)
    backtrack=int(obs%solver_diagnostics%backtracking_attempts,c_int)
    retries=int(obs%solver_diagnostics%internal_retries,c_int)
    constitutive=int(obs%solver_diagnostics%constitutive_evaluations,c_int)
    eq_available=merge(1_c_int,0_c_int,obs%solver_equation_residual_available)
    temporal_enabled=merge(1_c_int,0_c_int,obs%temporal_indicator_enabled)
    temporal_status=int(obs%temporal_indicator_status,c_int)
    temporal_available=merge(1_c_int,0_c_int,obs%temporal_indicator_available)
    certificate_available=merge(1_c_int,0_c_int,obs%temporal_certificate_available)
    budget_supplied=merge(1_c_int,0_c_int,obs%temporal_head_budget_supplied)
    budget_valid=merge(1_c_int,0_c_int,obs%temporal_head_budget_valid)
    eq_residual=real(obs%solver_equation_residual,c_double)
    head_bound=real(obs%temporal_head_inf_bound,c_double)
    budget=real(obs%temporal_head_budget,c_double)
    normalized=real(obs%temporal_normalized_indicator,c_double)
    top_flux=real(obs%top_flux,c_double)
    bottom_flux=real(obs%bottom_flux,c_double)
    fgc44_repro02_observation_c=0_c_int
  end function fgc44_repro02_observation_c

  integer(c_int) function fgc44_approx04_configure_case_c(h0,tr,ts,alpha,nvg,ksat,lambda) &
       bind(C,name="fgc44_approx04_configure_case_c")
    real(c_double), value, intent(in) :: h0,tr,ts,alpha,nvg,ksat,lambda
    fgc44_approx04_configure_case_c=1_c_int
    if(initialized)return
    REPRO_H0_CM=real(h0,real64); REPRO_TR=real(tr,real64); REPRO_TS=real(ts,real64)
    REPRO_ALPHA=real(alpha,real64); REPRO_NVG=real(nvg,real64)
    REPRO_KSAT=real(ksat,real64); REPRO_LAMBDA=real(lambda,real64)
    fgc44_approx04_configure_case_c=0_c_int
  end function fgc44_approx04_configure_case_c

  integer(c_int) function fgc44_approx04_predictor_q_c(q) bind(C,name="fgc44_approx04_predictor_q_c")
    real(c_double), intent(out) :: q
    type(fmr_b110_physical_parameters_t) :: p
    type(b110_default_mvg_parameters_t) :: hp
    real(real64) :: kval
    logical :: ok
    q=0.0_c_double
    fgc44_approx04_predictor_q_c=1_c_int
    if(initialized)return
    call initialize_parameters(p,2)
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call evaluate_b110_default_mvg_conductivity(hp,1,REPRO_H0_CM,kval,ok)
    if(.not.ok)return
    q=-real(kval,c_double)
    fgc44_approx04_predictor_q_c=0_c_int
  end function fgc44_approx04_predictor_q_c

  integer(c_int) function fgc44_approx04_p1b_state_c(heads,theta) bind(C,name="fgc44_approx04_p1b_state_c")
    real(c_double), intent(out) :: heads(numnod),theta(numnod)
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    fgc44_approx04_p1b_state_c=1_c_int
    heads=0.0_c_double; theta=0.0_c_double
    if(.not.initialized)return
    call committed%snapshot(snapshot,available)
    if(.not.available .or. .not.allocated(snapshot))return
    select type(state=>snapshot)
    type is(fmr_b110_physical_state_t)
      if(.not.allocated(state%pressure_head) .or. .not.allocated(state%water_content))return
      heads=state%pressure_head
      theta=state%water_content
    class default
      return
    end select
    fgc44_approx04_p1b_state_c=0_c_int
  end function fgc44_approx04_p1b_state_c

"""
if needle not in src: raise SystemExit("contains seam missing")
src=src.replace(needle,insert,1)
p.write_text(src)
PY

cat > "$BUILD/py/bench.py" <<'PY'
import ctypes,json,os,sys
from pathlib import Path
sys.path.insert(0,str(Path("tests/fgc/support").resolve()))
from fgc44_real_swap_ctypes import Fgc44RealSwap
MATERIALS={
"B01":(0.02,0.427494,0.021659,1.734737,31.225016,0.98087),
"B12":(0.01,0.529749,0.016562,1.090671,2.245895,-4.493581),
"O05":(0.01,0.336701,0.030304,2.887502,17.418504,0.0736),
"O14":(0.01,0.393878,0.003288,1.616573,2.495984,0.514012),
}
material,h0_s,offset_s,mode=sys.argv[1:]
h0=float(h0_s); offset_cm=float(offset_s)
swap=Fgc44RealSwap(Path(os.environ["FGC44_SWAP_LIB"]))
cfg=swap.lib.fgc44_approx04_configure_case_c
cfg.restype=ctypes.c_int; cfg.argtypes=[ctypes.c_double]*7
tr,ts,alpha,nvg,ksat,lamb=MATERIALS[material]
if cfg(h0,tr,ts,alpha,nvg,ksat,lamb): raise RuntimeError("configure failed")
predfn=swap.lib.fgc44_approx04_predictor_q_c
predfn.restype=ctypes.c_int; predfn.argtypes=[ctypes.POINTER(ctypes.c_double)]
predictor_q=ctypes.c_double()
if predfn(ctypes.byref(predictor_q)): raise RuntimeError("predictor q failed")
_,_,href=swap.initialize_configured(1.0e-4,predictor_q.value)
q=ctypes.c_double()
head=float(href+offset_cm/100.0)
status=-1
floor={}
if mode=="TRANSACTION":
    status=int(swap.lib.fgc44_swap_trial_c(head,ctypes.byref(q)))
elif mode=="FLOOR":
    fnf=swap.lib.fgc44_repro02_floor_c
    fi=[ctypes.c_int() for _ in range(10)]
    fr=[ctypes.c_double() for _ in range(3)]
    fnf.restype=ctypes.c_int
    fnf.argtypes=[ctypes.c_double,*([ctypes.POINTER(ctypes.c_int)]*10),*([ctypes.POINTER(ctypes.c_double)]*3)]
    rc=fnf(head,*[ctypes.byref(x) for x in fi],*[ctypes.byref(x) for x in fr])
    if rc: raise RuntimeError(f"floor call failed {rc}")
    namesf=["floor_status","sample_valid","physical_advances","nonlinear","internal_retries","headcalc","jacobian","linear","backtrack","mass_complete"]
    floor={k:v.value for k,v in zip(namesf,fi)}
    for k,v in zip(["mass_residual","bottom_exchange","terminal_flux"],fr): floor[k]=v.value
else:
    raise RuntimeError("bad mode")

fn=swap.lib.fgc44_repro02_observation_c
ints=[ctypes.c_int() for _ in range(15)]
reals=[ctypes.c_double() for _ in range(6)]
fn.restype=ctypes.c_int
fn.argtypes=[*([ctypes.POINTER(ctypes.c_int)]*15),*([ctypes.POINTER(ctypes.c_double)]*6)]
if fn(*[ctypes.byref(x) for x in ints],*[ctypes.byref(x) for x in reals]):
    raise RuntimeError("observation query failed")
names=["solver_executed","solver_status","nonlinear","jacobian","linear","backtrack","retries","constitutive",
       "eq_available","temporal_enabled","temporal_status","temporal_available","certificate_available","budget_supplied","budget_valid"]
d={k:v.value for k,v in zip(names,ints)}
for k,v in zip(["eq_residual","head_bound","budget","normalized","top_flux","bottom_flux"],reals): d[k]=v.value
d.update(material=material,h0=h0,offset_cm=offset_cm,href=href,predictor_q=predictor_q.value,participant_status=status,q=q.value,mode=mode,floor=floor)
print("REPRO02_R9_RAW|"+json.dumps(d,separators=(",",":")))
PY

COMMON=(-std=f2008 -ffree-line-length-none -O2 -fPIC -fopenmp)
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
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_b110_root_sink_provider.f90
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
  src/runtime/mod_modflow6_swap_predictor_origin.f90
  src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
  src/runtime/mod_modflow6_linear_response_backend.f90
  src/runtime/mod_modflow6_api_binding.f90
  src/adapter/mod_modflow6_fgc34_c_bridge.f90
  "$BUILD/lib/mod_fgc44_real_swap_c_bridge.f90"
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/lib/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD/lib" -I "$BUILD/lib" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$BUILD/lib/libswap.so" || fail "link"

export PYTHONPATH="$ROOT/tests/fgc/support"
OUT="$BUILD/r9.txt"; : > "$OUT"
cases=("B01|wet|-10" "B01|mid|-75" "B12|wet|-10" "O05|wet|-10" "O14|wet|-10" "O14|mid|-75")
offsets=(-0.001 0 0.001)
modes=(FLOOR TRANSACTION)
reps=3
for case_spec in "${cases[@]}"; do
  IFS='|' read -r material regime h0 <<< "$case_spec"
  for offset in "${offsets[@]}"; do
    for mode in "${modes[@]}"; do
      for rep in $(seq 1 "$reps"); do
        raw="$(FGC44_SWAP_LIB="$BUILD/lib/libswap.so" python3 "$BUILD/py/bench.py" "$material" "$h0" "$offset" "$mode")" || { printf '%s\n' "$raw" >&2; fail "$material $regime $offset $mode"; }
        line="$(printf '%s\n' "$raw" | grep '^REPRO02_R9_RAW|' | tail -1)"
        [[ -n "$line" ]] || fail "missing R9 record"
        printf '%s|REGIME=%s|REP=%s\n' "$line" "$regime" "$rep" | tee -a "$OUT"
      done
    done
  done
done

python3 - "$OUT" <<'PY'
import collections,json,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("REPRO02_R9_RAW|"): continue
    payload,regrep=line.strip().split("|REGIME=")
    reg,rep=regrep.split("|REP=")
    d=json.loads(payload.split("|",1)[1]); d["regime"]=reg; d["rep"]=int(rep); rows.append(d)
if len(rows)!=108: raise SystemExit(f"expected 108 rows, got {len(rows)}")
groups=collections.defaultdict(list)
for d in rows: groups[(d["material"],d["regime"],d["offset_cm"],d["mode"])].append(d)
for key,rs in sorted(groups.items()):
    if key[3]=="FLOOR":
        sig=collections.Counter((r["floor"]["floor_status"],r["floor"]["sample_valid"],r["floor"]["nonlinear"],r["floor"]["backtrack"]) for r in rs)
        if len(sig)!=1: raise SystemExit(f"nondeterministic floor {key}: {sig}")
        r=rs[0]; f=r["floor"]
        print(f"REPRO02_R9_POINT|MATERIAL={key[0]}|REGIME={key[1]}|OFFSET_CM={key[2]:.6f}|ARM=FLOOR"
              f"|STATUS={f['floor_status']}|VALID={f['sample_valid']}|ADVANCES={f['physical_advances']}"
              f"|NONLINEAR={f['nonlinear']}|INTERNAL_RETRIES={f['internal_retries']}|HEADCALC={f['headcalc']}"
              f"|JACOBIAN={f['jacobian']}|LINEAR={f['linear']}|BACKTRACK={f['backtrack']}"
              f"|MASS_COMPLETE={f['mass_complete']}|MASS_RESIDUAL={f['mass_residual']:.17e}")
    else:
        sig=collections.Counter((r["participant_status"],r["solver_status"],r["nonlinear"],r["backtrack"]) for r in rs)
        if len(sig)!=1: raise SystemExit(f"nondeterministic transaction {key}: {sig}")
        r=rs[0]
        print(f"REPRO02_R9_POINT|MATERIAL={key[0]}|REGIME={key[1]}|OFFSET_CM={key[2]:.6f}|ARM=TRANSACTION"
              f"|PARTICIPANT_STATUS={r['participant_status']}|SOLVER_STATUS={r['solver_status']}"
              f"|NONLINEAR={r['nonlinear']}|BACKTRACK={r['backtrack']}")
floor_success=sum(1 for k,rs in groups.items() if k[3]=="FLOOR" and rs[0]["floor"]["floor_status"]==0)
tx_success=sum(1 for k,rs in groups.items() if k[3]=="TRANSACTION" and rs[0]["participant_status"]==0)
print(f"REPRO02_R9_SUMMARY|FLOOR_OK={floor_success}|TRANSACTION_OK={tx_success}|TOTAL_PER_ARM=18")
print("FPE_REPRO02_R9=PASS")
PY
