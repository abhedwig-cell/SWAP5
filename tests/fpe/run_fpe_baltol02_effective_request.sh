#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-baltol02-g12-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/lib" "$BUILD/py"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "BALTOL02_G12_FAIL $*" >&2; exit 1; }

cp tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90 "$BUILD/lib/mod_fgc44_real_swap_c_bridge.f90"
python3 - "$BUILD/lib/mod_fgc44_real_swap_c_bridge.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
src=src.replace("  use mod_canonical_contracts, only: canonical_numerical_config_t\n",
                "  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_forcing_t\n",1)
src=src.replace("  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t\n",
                "  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t\n"
                "  use mod_groundwater_swap_forcing_adapter, only: GW_SWAP_FORCING_OK\n",1)
src=src.replace(
"  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &\n"
"       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider\n",
"  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &\n"
"       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity\n",1)

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
src=src.replace("    p%max_iterations=16; p%max_backtracking=8; p%min_step_duration=1.0e-8_real64",
                "    p%max_iterations=48; p%max_backtracking=16; p%min_step_duration=1.0e-10_real64",1)

src=src.replace(
"  public :: fgc44_predictor_run_diagnostics_c\n",
"  public :: fgc44_predictor_run_diagnostics_c\n"
"  public :: fgc44_approx04_configure_case_c, fgc44_approx04_p1b_state_c, fgc44_approx04_predictor_q_c\n"
"  public :: fgc44_temporal03_dynamic_origin_c, fgc44_shortstep01_single_c\n",1)
needle="contains\n\n"
insert="""contains

  integer(c_int) function fgc44_temporal03_dynamic_origin_c(imbalance,max_abs_derivative,mass_residual,origin_head_m) &
       bind(C,name="fgc44_temporal03_dynamic_origin_c")
    real(c_double), value, intent(in) :: imbalance
    real(c_double), intent(out) :: max_abs_derivative,mass_residual,origin_head_m
    class(transaction_state_t), allocatable :: snap,hsnap
    type(fmr_b110_physical_state_t) :: base,hstate
    type(kernel_committed_state_t) :: plain
    type(fmr_serialized_reference_backend_t) :: history_backend
    type(fmr_template_t) :: floor_template
    type(fmr_b110_physical_forcing_t) :: history_forcing
    type(kernel_reference_floor_result_t) :: r
    type(kernel_reference_floor_candidate_t) :: c
    type(kernel_diagnostics_t) :: d
    type(fmr_serialized_physical_observation_t) :: obs
    real(real64), allocatable :: deriv(:)
    logical :: available,ok
    integer :: status

    fgc44_temporal03_dynamic_origin_c=1_c_int
    max_abs_derivative=0.0_c_double; mass_residual=0.0_c_double; origin_head_m=0.0_c_double
    if(.not.initialized)return
    if(.not.ieee_is_finite(real(imbalance,real64)) .or. abs(imbalance)<1.0e-6_c_double)return
    if(participant%has_live_candidate())return

    call committed%snapshot(snap,available)
    if(.not.available .or. .not.allocated(snap))return
    select type(p=>snap)
    class is(fmr_b110_physical_state_t)
      base%active_nodes=p%active_nodes
      allocate(base%pressure_head(p%active_nodes),base%water_content(p%active_nodes))
      base%pressure_head=p%pressure_head; base%water_content=p%water_content
      base%ponding_depth=p%ponding_depth; base%groundwater_level=p%groundwater_level
    class default
      return
    end select

    call fmr_new_b110_committed_state(plain,COLUMN_ID,base,window%t0,ok)
    if(.not.ok)return
    floor_template=template
    floor_template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    floor_template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    history_forcing=base_forcing
    history_forcing%top_flux=active_predictor_qbot*(1.0_real64+real(imbalance,real64))
    history_forcing%bottom_flux=active_predictor_qbot
    call history_backend%initialize(top)
    call history_backend%run_reference_floor_sample(column,floor_template,predictor_parameters,plain,history_forcing, &
         window%t0,window%t1,1.0e-12_real64,r,c,d)
    if(.not.r%sample_valid .or. .not.r%mass%complete .or. .not.c%ready())return
    call c%snapshot(hsnap,available)
    if(.not.available .or. .not.allocated(hsnap))return
    select type(p=>hsnap)
    class is(fmr_b110_physical_state_t)
      hstate%active_nodes=p%active_nodes
      allocate(hstate%pressure_head(p%active_nodes),hstate%water_content(p%active_nodes))
      hstate%pressure_head=p%pressure_head; hstate%water_content=p%water_content
      hstate%ponding_depth=p%ponding_depth; hstate%groundwater_level=p%groundwater_level
    class default
      return
    end select
    if(hstate%active_nodes/=base%active_nodes)return
    allocate(deriv(hstate%active_nodes))
    deriv=(hstate%pressure_head-base%pressure_head)/(window%t1-window%t0)
    if(any(.not.ieee_is_finite(deriv)))return
    max_abs_derivative=maxval(abs(deriv))
    if(max_abs_derivative<=0.0_real64)return
    mass_residual=r%mass%residual
    origin_head_m=hstate%pressure_head(hstate%active_nodes)/100.0_real64

    call fmr_new_b110_temporal_indicator_committed_state(committed,COLUMN_ID,hstate,window%t1,ok,deriv)
    if(.not.ok)return
    window%t0=window%t1
    window%t1=window%t0+active_duration_day
    call participant%capture_origin(committed,status)
    if(status/=GW_SWAP_PARTICIPANT_OK)return
    fgc44_temporal03_dynamic_origin_c=0_c_int
  end function fgc44_temporal03_dynamic_origin_c

  integer(c_int) function fgc44_shortstep01_single_c(prescribed_head_m,step_duration,balance_tolerance,floor_status,sample_valid, &
       nonlinear,jacobian,linear,backtrack,internal_retries,mass_complete,mass_residual,terminal_flux,heads,theta, &
       effective_compartment_tolerance,effective_total_tolerance) &
       bind(C,name="fgc44_shortstep01_single_c")
    real(c_double), value, intent(in) :: prescribed_head_m,step_duration,balance_tolerance
    integer(c_int), intent(out) :: floor_status,sample_valid,nonlinear,jacobian,linear,backtrack,internal_retries,mass_complete
    real(c_double), intent(out) :: mass_residual,terminal_flux
    real(c_double), intent(out) :: heads(numnod),theta(numnod)
    real(c_double), intent(out) :: effective_compartment_tolerance,effective_total_tolerance
    class(transaction_state_t), allocatable :: snap,candidate_snap
    class(canonical_forcing_t), allocatable :: generic_forcing
    type(fmr_b110_physical_state_t) :: base
    type(kernel_committed_state_t) :: plain
    type(fmr_serialized_reference_backend_t) :: floor_backend
    type(fmr_template_t) :: floor_template
    type(fmr_b110_physical_forcing_t) :: floor_forcing
    type(fmr_b110_physical_parameters_t) :: floor_parameters
    type(kernel_reference_floor_result_t) :: r
    type(kernel_reference_floor_candidate_t) :: c
    type(kernel_diagnostics_t) :: d
    logical :: available,ok
    integer :: status

    fgc44_shortstep01_single_c=1_c_int
    floor_status=-1_c_int; sample_valid=0_c_int; nonlinear=0_c_int; jacobian=0_c_int
    linear=0_c_int; backtrack=0_c_int; internal_retries=0_c_int; mass_complete=0_c_int
    mass_residual=0.0_c_double; terminal_flux=0.0_c_double
    heads=0.0_c_double; theta=0.0_c_double
    effective_compartment_tolerance=0.0_c_double; effective_total_tolerance=0.0_c_double
    if(.not.initialized)return
    if(.not.ieee_is_finite(real(prescribed_head_m,real64)) .or. &
       .not.ieee_is_finite(real(step_duration,real64)) .or. step_duration<=0.0_c_double .or. &
       .not.ieee_is_finite(real(balance_tolerance,real64)) .or. balance_tolerance<=0.0_c_double)return
    if(participant%has_live_candidate())return

    call committed%snapshot(snap,available)
    if(.not.available .or. .not.allocated(snap))return
    select type(p=>snap)
    class is(fmr_b110_physical_state_t)
      base%active_nodes=p%active_nodes
      allocate(base%pressure_head(p%active_nodes),base%water_content(p%active_nodes))
      base%pressure_head=p%pressure_head; base%water_content=p%water_content
      base%ponding_depth=p%ponding_depth; base%groundwater_level=p%groundwater_level
    class default
      return
    end select

    call fmr_new_b110_committed_state(plain,COLUMN_ID,base,window%t0,ok)
    if(.not.ok)return
    floor_template=template
    floor_template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    floor_template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    call materializer%materialize(real(prescribed_head_m,real64),datum,generic_forcing,status)
    if(status/=GW_SWAP_FORCING_OK .or. .not.allocated(generic_forcing))return
    select type(f=>generic_forcing)
    type is(fmr_b110_physical_forcing_t)
      floor_forcing=f
    class default
      return
    end select

    floor_parameters=corrector_parameters
    floor_parameters%compartment_balance_tolerance=real(balance_tolerance,real64)
    floor_parameters%total_balance_tolerance=real(balance_tolerance,real64)
    call floor_backend%initialize(top)
    call floor_backend%run_reference_floor_sample(column,floor_template,floor_parameters,plain,floor_forcing, &
         window%t0,window%t0+real(step_duration,real64),1.0e-12_real64,r,c,d)

    floor_status=int(r%status,c_int)
    sample_valid=merge(1_c_int,0_c_int,r%sample_valid)
    nonlinear=int(r%nonlinear_iterations,c_int)
    jacobian=int(r%jacobian_builds,c_int)
    linear=int(r%linear_solves,c_int)
    backtrack=int(r%backtracking_attempts,c_int)
    internal_retries=int(r%internal_retries,c_int)
    mass_complete=merge(1_c_int,0_c_int,r%mass%complete)
    mass_residual=real(r%mass%residual,c_double)
    terminal_flux=real(r%terminal_bottom_outward_flux_native,c_double)
    obs=floor_backend%observation()
    effective_compartment_tolerance=real(obs%effective_reference_compartment_balance_tolerance,c_double)
    effective_total_tolerance=real(obs%effective_reference_total_balance_tolerance,c_double)
    if(r%sample_valid .and. c%ready())then
      call c%snapshot(candidate_snap,available)
      if(available .and. allocated(candidate_snap))then
        select type(p=>candidate_snap)
        class is(fmr_b110_physical_state_t)
          if(allocated(p%pressure_head) .and. allocated(p%water_content))then
            heads=p%pressure_head; theta=p%water_content
          end if
        class default
          continue
        end select
      end if
    end if
    fgc44_shortstep01_single_c=0_c_int
  end function fgc44_shortstep01_single_c

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
import ctypes,json,os,sys,math
from pathlib import Path
sys.path.insert(0,str(Path("tests/fgc/support").resolve()))
from fgc44_real_swap_ctypes import Fgc44RealSwap
MATERIAL=(0.02,0.427494,0.021659,1.734737,31.225016,0.98087)
dt=float(sys.argv[1]); configured=float(sys.argv[2])
swap=Fgc44RealSwap(Path(os.environ["FGC44_SWAP_LIB"]))
cfg=swap.lib.fgc44_approx04_configure_case_c
cfg.restype=ctypes.c_int; cfg.argtypes=[ctypes.c_double]*7
tr,ts,alpha,nvg,ksat,lamb=MATERIAL
if cfg(-10.0,tr,ts,alpha,nvg,ksat,lamb): raise RuntimeError("configure failed")
predfn=swap.lib.fgc44_approx04_predictor_q_c
predfn.restype=ctypes.c_int; predfn.argtypes=[ctypes.POINTER(ctypes.c_double)]
predictor_q=ctypes.c_double()
if predfn(ctypes.byref(predictor_q)): raise RuntimeError("predictor q failed")
swap.initialize_configured(1.0e-4,predictor_q.value)
dyn=swap.lib.fgc44_temporal03_dynamic_origin_c
dyn.restype=ctypes.c_int
dyn.argtypes=[ctypes.c_double,*([ctypes.POINTER(ctypes.c_double)]*3)]
rate=ctypes.c_double(); origin_mass=ctypes.c_double(); origin_head=ctypes.c_double()
if dyn(0.1,ctypes.byref(rate),ctypes.byref(origin_mass),ctypes.byref(origin_head)):
    raise RuntimeError("dynamic origin failed")
fn=swap.lib.fgc44_shortstep01_single_c
fn.restype=ctypes.c_int
ints=[ctypes.c_int() for _ in range(8)]
reals=[ctypes.c_double() for _ in range(4)]
heads=(ctypes.c_double*4)(); theta=(ctypes.c_double*4)()
fn.argtypes=[ctypes.c_double,ctypes.c_double,ctypes.c_double,*([ctypes.POINTER(ctypes.c_int)]*8),
             *([ctypes.POINTER(ctypes.c_double)]*2),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double),
             ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
rc=fn(origin_head.value+0.001/100.0,dt,configured,*[ctypes.byref(x) for x in ints],
      ctypes.byref(reals[0]),ctypes.byref(reals[1]),heads,theta,ctypes.byref(reals[2]),ctypes.byref(reals[3]))
if rc: raise RuntimeError(f"single step setup failed {rc}")
expected=max(configured,2.8e-16/dt)
print("BALTOL02_G12_RAW|"+json.dumps({
 "dt":dt,"configured":configured,"expected":expected,
 "effective_compartment":reals[2].value,"effective_total":reals[3].value,
 "floor_status":ints[0].value
},separators=(",",":")))
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
OUT="$BUILD/g12.txt"; : > "$OUT"
specs=(
  "1e-3|1e-12"
  "1e-4|1e-12"
  "6.25e-6|1e-12"
  "6.25e-6|1e-10"
)
for spec in "${specs[@]}"; do
  IFS='|' read -r dt configured <<< "$spec"
  raw="$(FGC44_SWAP_LIB="$BUILD/lib/libswap.so" python3 "$BUILD/py/bench.py" "$dt" "$configured")" || { printf '%s\n' "$raw" >&2; fail "$spec"; }
  line="$(printf '%s\n' "$raw" | grep '^BALTOL02_G12_RAW|' | tail -1)"
  [[ -n "$line" ]] || fail "missing G12 record"
  printf '%s\n' "$line" | tee -a "$OUT"
done

python3 - "$OUT" <<'PY'
import json,math,sys
rows=[]
for line in open(sys.argv[1]):
    if line.startswith("BALTOL02_G12_RAW|"):
        rows.append(json.loads(line.split("|",1)[1]))
if len(rows)!=4: raise SystemExit(f"expected 4 rows, got {len(rows)}")
for r in rows:
    e=r["expected"]
    for key in ("effective_compartment","effective_total"):
        a=r[key]
        if a!=e and not math.isclose(a,e,rel_tol=0.0,abs_tol=0.0):
            raise SystemExit(f"{key} mismatch: {r}")
    print(f"BALTOL02_G12_POINT|DT={r['dt']:.17e}|CONFIGURED={r['configured']:.17e}|EXPECTED={e:.17e}"
          f"|EFFECTIVE_COMPARTMENT={r['effective_compartment']:.17e}|EFFECTIVE_TOTAL={r['effective_total']:.17e}")
# Explicit preservation / scaling guards.
a=next(r for r in rows if r["dt"]==1e-3 and r["configured"]==1e-12)
if a["effective_compartment"]!=1e-12: raise SystemExit("strict-preservation guard failed")
b=next(r for r in rows if r["dt"]==1e-4 and r["configured"]==1e-12)
if b["effective_compartment"]!=2.8e-12: raise SystemExit("scaled-floor guard failed")
c=next(r for r in rows if r["dt"]==6.25e-6 and r["configured"]==1e-10)
if c["effective_compartment"]!=1e-10: raise SystemExit("configured-looser guard failed")
print("FPE_BALTOL02_G12=PASS")
PY
