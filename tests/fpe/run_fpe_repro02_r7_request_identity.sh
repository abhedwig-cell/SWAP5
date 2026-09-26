#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-repro02-r7-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/lib" "$BUILD/py"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "REPRO02_R7_FAIL $*" >&2; exit 1; }

cp tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90 "$BUILD/lib/mod_fgc44_real_swap_c_bridge.f90"
cp src/runtime/mod_fmr_serialized_reference_backend.f90 "$BUILD/lib/mod_fmr_serialized_reference_backend.f90"
python3 - "$BUILD/lib/mod_fmr_serialized_reference_backend.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
src=src.replace(
"    real(real64) :: rossfast_temporal_indicator, effective_bottom_flux\n",
"    real(real64) :: rossfast_temporal_indicator, effective_bottom_flux\n"
"    real(real64), allocatable :: repro_theta(:),repro_k(:),repro_c(:),repro_dkdh(:),repro_source(:),repro_sink(:)\n"
"    real(real64) :: repro_top_flux,repro_surface_head,repro_runoff\n"
"    integer :: repro_i\n",1)
needle="""    if (self%trajectory_direction_requested .and. self%trajectory_provenance_valid) then
"""
insert="""    if (abs(step_duration-1.0e-4_real64) <= 64.0_real64*epsilon(1.0_real64)) then
      allocate(repro_theta(request%base_state%active_nodes),repro_k(request%base_state%active_nodes), &
           repro_c(request%base_state%active_nodes),repro_dkdh(request%base_state%active_nodes), &
           repro_source(request%base_state%active_nodes),repro_sink(request%base_state%active_nodes))
      call request%evaluation%constitutive%evaluate(request%base_state%pressure_head,repro_theta,repro_k,repro_c,repro_dkdh)
      call request%evaluation%source_sink%evaluate(request%base_state%pressure_head,request%base_state%water_content, &
           repro_source,repro_sink)
      call request%evaluation%top_boundary%evaluate(request%base_state%pressure_head(1),request%base_state%water_content(1), &
           request%boundary,repro_top_flux,repro_surface_head,repro_runoff)
      write(*,'(*(g0))') 'REPRO02_R7_SERIAL_META|STEP=',request%step_duration,'|N=',request%base_state%active_nodes, &
           '|POND=',request%base_state%ponding_depth,'|GWL=',request%base_state%groundwater_level, &
           '|TOP_MODE=',request%boundary%top_mode,'|BOTTOM_MODE=',request%boundary%bottom_mode, &
           '|TOP_FLUX=',request%boundary%top_flux,'|TOP_HEAD=',request%boundary%top_head, &
           '|BOTTOM_FLUX=',request%boundary%bottom_flux,'|BOTTOM_HEAD=',request%boundary%bottom_head, &
           '|MAXIT=',request%numerical%max_iterations,'|MAXBT=',request%numerical%max_backtracking, &
           '|KIMPL=',request%numerical%conductivity_implicit_mode,'|KMEAN=',request%numerical%conductivity_mean_method, &
           '|MINSTEP=',request%numerical%min_step_duration,'|CBAL=',request%numerical%compartment_balance_tolerance, &
           '|TBAL=',request%numerical%total_balance_tolerance,'|HABS=',request%numerical%head_abs_tolerance, &
           '|HREL=',request%numerical%head_rel_tolerance,'|PONDTOL=',request%numerical%ponding_tolerance, &
           '|MACRO=',request%physical%macropore_active,'|TOP_EVAL_FLUX=',repro_top_flux, &
           '|TOP_EVAL_HEAD=',repro_surface_head,'|TOP_EVAL_RUNOFF=',repro_runoff
      do repro_i=1,request%base_state%active_nodes
        write(*,'(*(g0))') 'REPRO02_R7_SERIAL_NODE|I=',repro_i,'|Z=',request%parameters%z(repro_i), &
             '|DZ=',request%parameters%dz(repro_i),'|DIST=',request%parameters%node_distance(repro_i), &
             '|HEAD=',request%base_state%pressure_head(repro_i),'|WATER=',request%base_state%water_content(repro_i), &
             '|THETA_EVAL=',repro_theta(repro_i),'|K=',repro_k(repro_i),'|C=',repro_c(repro_i), &
             '|DKDH=',repro_dkdh(repro_i),'|SOURCE=',repro_source(repro_i),'|SINK=',repro_sink(repro_i)
      end do
    end if

"""
if needle not in src: raise SystemExit("R7 serialized request seam missing")
src=src.replace(needle,insert+needle,1)
p.write_text(src)
PY
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
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &\n"
"       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state\n",
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &\n"
"       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &\n"
"       fmr_new_b110_temporal_indicator_committed_state\n",1)

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
"  real(real64), save :: REPRO_ALPHA=0.0135_real64, REPRO_LAMBDA=0.365_real64, REPRO_NVG=1.455_real64\n"
"  integer, save :: REPRO_MAX_ITER=16, REPRO_MAX_BACKTRACK=8\n"
"  real(real64), save :: REPRO_MIN_STEP=1.0e-8_real64\n",1)
old="""      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
"""
new="""      p%cofgen(1,k)=REPRO_TR; p%cofgen(2,k)=REPRO_TS; p%cofgen(3,k)=REPRO_KSAT
      p%cofgen(4,k)=REPRO_ALPHA; p%cofgen(5,k)=REPRO_LAMBDA; p%cofgen(6,k)=REPRO_NVG
"""
if old not in src: raise SystemExit("material seam missing")
src=src.replace(old,new,1)
src=src.replace(
"    p%max_iterations=16; p%max_backtracking=8; p%min_step_duration=1.0e-8_real64",
"    p%max_iterations=REPRO_MAX_ITER; p%max_backtracking=REPRO_MAX_BACKTRACK; p%min_step_duration=REPRO_MIN_STEP"
)

src=src.replace(
"  public :: fgc44_predictor_run_diagnostics_c\n",
"  public :: fgc44_predictor_run_diagnostics_c\n"
"  public :: fgc44_approx04_configure_case_c, fgc44_approx04_p1b_state_c, fgc44_approx04_predictor_q_c\n"
"  public :: fgc44_repro02_observation_c, fgc44_repro02_numerical_controls_c\n",1)
needle="contains\n\n"
insert="""contains

  integer(c_int) function fgc44_repro02_numerical_controls_c(max_iter,max_backtrack,min_step) bind(C,name="fgc44_repro02_numerical_controls_c")
    integer(c_int), value, intent(in) :: max_iter,max_backtrack
    real(c_double), value, intent(in) :: min_step
    fgc44_repro02_numerical_controls_c=1_c_int
    if(initialized)return
    if(max_iter<=0_c_int .or. max_backtrack<=0_c_int .or. min_step<=0.0_c_double)return
    REPRO_MAX_ITER=int(max_iter)
    REPRO_MAX_BACKTRACK=int(max_backtrack)
    REPRO_MIN_STEP=real(min_step,real64)
    fgc44_repro02_numerical_controls_c=0_c_int
  end function fgc44_repro02_numerical_controls_c

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
material,h0_s,offset_s,minstep_s=sys.argv[1:]
h0=float(h0_s); offset_cm=float(offset_s); maxit=48; maxbt=16; minstep=float(minstep_s)
swap=Fgc44RealSwap(Path(os.environ["FGC44_SWAP_LIB"]))
cfg=swap.lib.fgc44_approx04_configure_case_c
cfg.restype=ctypes.c_int; cfg.argtypes=[ctypes.c_double]*7
tr,ts,alpha,nvg,ksat,lamb=MATERIALS[material]
if cfg(h0,tr,ts,alpha,nvg,ksat,lamb): raise RuntimeError("configure failed")
limitfn=swap.lib.fgc44_repro02_numerical_controls_c
limitfn.restype=ctypes.c_int; limitfn.argtypes=[ctypes.c_int,ctypes.c_int,ctypes.c_double]
if limitfn(maxit,maxbt,minstep): raise RuntimeError("numerical control configuration failed")
predfn=swap.lib.fgc44_approx04_predictor_q_c
predfn.restype=ctypes.c_int; predfn.argtypes=[ctypes.POINTER(ctypes.c_double)]
predictor_q=ctypes.c_double()
if predfn(ctypes.byref(predictor_q)): raise RuntimeError("predictor q failed")
_,_,href=swap.initialize_configured(1.0e-4,predictor_q.value)
q=ctypes.c_double()
status=int(swap.lib.fgc44_swap_trial_c(float(href+offset_cm/100.0),ctypes.byref(q)))

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
d.update(material=material,h0=h0,offset_cm=offset_cm,maxit=maxit,maxbt=maxbt,minstep=minstep,href=href,predictor_q=predictor_q.value,participant_status=status,q=q.value)
print("REPRO02_R1_RAW|"+json.dumps(d,separators=(",",":")))
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
  "$BUILD/lib/mod_fmr_serialized_reference_backend.f90"
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

python3 - "$BUILD/direct.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fpe/test_fpe_approx01_tangent_matrix.f90").read_text()
src=src.replace(
"  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX\n",
"  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX\n"
"  use mod_b110_serialized_context_binding, only: bind_b110_serialized_legacy_context\n",1)
src=src.replace(
"  character(len=64) :: arg,material\n  integer :: i\n",
"  character(len=64) :: arg,material\n"
"  real(real64) :: ptheta(numnod),pk(numnod),pc(numnod),pdkdh(numnod),psource(numnod),psink(numnod)\n"
"  real(real64) :: ptop_flux,psurface_head,prunoff\n"
"  logical :: context_ok\n"
"  integer :: i\n",1)
needle="""  call solve_with_accepted_step_direction(solver,request,workspace,dreq,solve_result,dres)
"""
insert="""  context_ok=.true.
  call bind_b110_serialized_legacy_context(request,context_ok)
  if(.not.context_ok) error stop 'R7 direct context bind failed'
  call request%evaluation%constitutive%evaluate(request%base_state%pressure_head,ptheta,pk,pc,pdkdh)
  call request%evaluation%source_sink%evaluate(request%base_state%pressure_head,request%base_state%water_content,psource,psink)
  call request%evaluation%top_boundary%evaluate(request%base_state%pressure_head(1),request%base_state%water_content(1), &
       request%boundary,ptop_flux,psurface_head,prunoff)
  write(*,'(*(g0))') 'REPRO02_R7_DIRECT_META|STEP=',request%step_duration,'|N=',request%base_state%active_nodes, &
       '|POND=',request%base_state%ponding_depth,'|GWL=',request%base_state%groundwater_level, &
       '|TOP_MODE=',request%boundary%top_mode,'|BOTTOM_MODE=',request%boundary%bottom_mode, &
       '|TOP_FLUX=',request%boundary%top_flux,'|TOP_HEAD=',request%boundary%top_head, &
       '|BOTTOM_FLUX=',request%boundary%bottom_flux,'|BOTTOM_HEAD=',request%boundary%bottom_head, &
       '|MAXIT=',request%numerical%max_iterations,'|MAXBT=',request%numerical%max_backtracking, &
       '|KIMPL=',request%numerical%conductivity_implicit_mode,'|KMEAN=',request%numerical%conductivity_mean_method, &
       '|MINSTEP=',request%numerical%min_step_duration,'|CBAL=',request%numerical%compartment_balance_tolerance, &
       '|TBAL=',request%numerical%total_balance_tolerance,'|HABS=',request%numerical%head_abs_tolerance, &
       '|HREL=',request%numerical%head_rel_tolerance,'|PONDTOL=',request%numerical%ponding_tolerance, &
       '|MACRO=',request%physical%macropore_active,'|TOP_EVAL_FLUX=',ptop_flux, &
       '|TOP_EVAL_HEAD=',psurface_head,'|TOP_EVAL_RUNOFF=',prunoff
  do i=1,numnod
    write(*,'(*(g0))') 'REPRO02_R7_DIRECT_NODE|I=',i,'|Z=',request%parameters%z(i), &
         '|DZ=',request%parameters%dz(i),'|DIST=',request%parameters%node_distance(i), &
         '|HEAD=',request%base_state%pressure_head(i),'|WATER=',request%base_state%water_content(i), &
         '|THETA_EVAL=',ptheta(i),'|K=',pk(i),'|C=',pc(i),'|DKDH=',pdkdh(i),'|SOURCE=',psource(i),'|SINK=',psink(i)
  end do
  call solver%solve(request,workspace,solve_result)
  dres%status=0
"""
if needle not in src: raise SystemExit("R7 direct solve seam missing")
src=src.replace(needle,insert,1)
# R7 is diagnostic: do not require direction publication, but direct physical solve must converge.
src=src.replace("  if(dres%status/=SW_STEP_DIRECTION_AVAILABLE .or. .not.dres%available) error stop 'matrix tangent unavailable'\n","")
src=src.replace("  if(.not.ieee_is_finite(dres%bottom_flux_derivative)) error stop 'matrix tangent nonfinite'\n","")
Path(sys.argv[1]).write_text(src)
PY
gfortran "${COMMON[@]}" -J "$BUILD/lib" -I "$BUILD/lib" -c "$BUILD/direct.f90" -o "$BUILD/lib/direct.o" || fail "compile direct R7"
gfortran -fopenmp -O2 "${objects[@]}" "$BUILD/lib/direct.o" -o "$BUILD/direct" || fail "link direct R7"

export PYTHONPATH="$ROOT/tests/fgc/support"
OUT="$BUILD/r7.txt"; : > "$OUT"
cases=("B01|wet|-10" "B01|mid|-75" "B12|wet|-10" "O05|wet|-10" "O14|wet|-10" "O14|mid|-75")
offsets=(-0.001 0 0.001)
reps=3
for case_spec in "${cases[@]}"; do
  IFS='|' read -r material regime h0 <<< "$case_spec"
  for offset in "${offsets[@]}"; do
    hbot="$(python3 - <<PY
print(float("$h0")+float("$offset"))
PY
)"
    for rep in $(seq 1 "$reps"); do
      sraw="$(FGC44_SWAP_LIB="$BUILD/lib/libswap.so" python3 "$BUILD/py/bench.py" "$material" "$h0" "$offset" "1e-10" 2>&1)" || { printf '%s\n' "$sraw" >&2; fail "serialized $material $regime $offset"; }
      printf '%s\n' "$sraw" | grep '^REPRO02_R7_SERIAL_' | sed "s/$/|MATERIAL=$material|REGIME=$regime|OFFSET_CM=$offset|REP=$rep|ARM=SERIAL/" >> "$OUT"
      draw="$("$BUILD/direct" "$material" "$h0" "$hbot" 2>&1)" || { printf '%s\n' "$draw" >&2; fail "direct $material $regime $offset"; }
      printf '%s\n' "$draw" | grep '^REPRO02_R7_DIRECT_' | sed "s/$/|MATERIAL=$material|REGIME=$regime|OFFSET_CM=$offset|REP=$rep|ARM=DIRECT/" >> "$OUT"
    done
  done
done

python3 - "$OUT" <<'PY'
import collections,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("REPRO02_R7_"): continue
    kind="META" if "_META|" in line else "NODE"
    d={"kind":kind}
    for p in line.strip().split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    rows.append(d)
meta=[r for r in rows if r["kind"]=="META"]
node=[r for r in rows if r["kind"]=="NODE"]
if len(meta)!=108: raise SystemExit(f"expected 108 meta rows, got {len(meta)}")
if len(node)!=432: raise SystemExit(f"expected 432 node rows, got {len(node)}")

def key(r): return (r["MATERIAL"],r["REGIME"],r["OFFSET_CM"],r["REP"],r["ARM"])
mg=collections.defaultdict(list); ng=collections.defaultdict(list)
for r in meta: mg[key(r)].append(r)
for r in node: ng[key(r)].append(r)
for k,v in mg.items():
    if len(v)!=1: raise SystemExit(f"meta multiplicity {k} {len(v)}")
for k,v in ng.items():
    if len(v)!=4: raise SystemExit(f"node multiplicity {k} {len(v)}")

meta_fields=["STEP","N","POND","GWL","TOP_MODE","BOTTOM_MODE","TOP_FLUX","TOP_HEAD","BOTTOM_FLUX","BOTTOM_HEAD",
             "MAXIT","MAXBT","KIMPL","KMEAN","MINSTEP","CBAL","TBAL","HABS","HREL","PONDTOL","MACRO",
             "TOP_EVAL_FLUX","TOP_EVAL_HEAD","TOP_EVAL_RUNOFF"]
node_fields=["Z","DZ","DIST","HEAD","WATER","THETA_EVAL","K","C","DKDH","SOURCE","SINK"]
all_div=[]
for material,regime,h0 in [("B01","wet",-10),("B01","mid",-75),("B12","wet",-10),("O05","wet",-10),("O14","wet",-10),("O14","mid",-75)]:
  for offset in ("-0.001","0","0.001"):
    for rep in ("1","2","3"):
      kd=(material,regime,offset,rep,"DIRECT"); ks=(material,regime,offset,rep,"SERIAL")
      d=mg[kd][0]; s=mg[ks][0]
      div=[]
      for f in meta_fields:
        if d[f]!=s[f]:
          try:
            if float(d[f])==float(s[f]): continue
          except ValueError: pass
          div.append(f"META:{f}:{d[f]}!={s[f]}")
      dn=sorted(ng[kd],key=lambda r:int(r["I"])); sn=sorted(ng[ks],key=lambda r:int(r["I"]))
      for a,b in zip(dn,sn):
        if a["I"]!=b["I"]: div.append("NODE_INDEX")
        for f in node_fields:
          if a[f]!=b[f]:
            try:
              if float(a[f])==float(b[f]): continue
            except ValueError: pass
            div.append(f"NODE{a['I']}:{f}:{a[f]}!={b[f]}")
      if div:
        all_div.append((material,regime,offset,rep,div))
        print(f"REPRO02_R7_COMPARE|MATERIAL={material}|REGIME={regime}|OFFSET_CM={float(offset):.6f}|REP={rep}|IDENTICAL=FALSE|DIVERGENCES={';'.join(div)}")
      else:
        print(f"REPRO02_R7_COMPARE|MATERIAL={material}|REGIME={regime}|OFFSET_CM={float(offset):.6f}|REP={rep}|IDENTICAL=TRUE|DIVERGENCES=NONE")

# Determinism: divergence signature must repeat exactly across the three reps.
groups=collections.defaultdict(list)
for material,regime,offset,rep,div in all_div:
    groups[(material,regime,offset)].append(tuple(div))
for case in [(m,r,o) for m,r,_ in [("B01","wet",-10),("B01","mid",-75),("B12","wet",-10),("O05","wet",-10),("O14","wet",-10),("O14","mid",-75)] for o in ("-0.001","0","0.001")]:
    sigs=groups.get(case,[])
    if sigs and (len(sigs)!=3 or len(set(sigs))!=1):
        raise SystemExit(f"nondeterministic divergence {case}: {sigs}")
points_with_div=sum(1 for case in groups if groups[case])
print(f"REPRO02_R7_SUMMARY|POINTS=18|POINTS_WITH_DIVERGENCE={points_with_div}|POINTS_IDENTICAL={18-points_with_div}")
print("FPE_REPRO02_R7=PASS")
PY
