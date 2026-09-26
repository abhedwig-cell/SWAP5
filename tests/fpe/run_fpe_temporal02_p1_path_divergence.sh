#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-temporal02-p1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/lib" "$BUILD/py"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "TEMPORAL02_P1_FAIL $*" >&2; exit 1; }

cp tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90 "$BUILD/lib/mod_fgc44_real_swap_c_bridge.f90"
cp src/transaction/mod_transaction_reference.f90 "$BUILD/lib/mod_transaction_reference.f90"
python3 - "$BUILD/lib/mod_transaction_reference.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
# Add a tiny test-only helper condition inside the model-certificate executor.
decl="""    integer :: retry_index
"""
repl="""    integer :: retry_index
    character(len=8) :: repro13_trace
    integer :: repro13_env_status
    logical :: repro13_enabled
"""
if decl not in src: raise SystemExit("R13 declaration seam missing")
# Only patch the declaration in execute_model_certificate_interval, not the earlier full/half executor.
pos=src.index("  subroutine execute_model_certificate_interval")
head=src[:pos]; tail=src[pos:]
if decl not in tail: raise SystemExit("R13 model-certificate declaration seam missing")
tail=tail.replace(decl,repl,1)
init="""    result%temporal_acceptance_source = TX_TEMPORAL_MODEL_CERTIFICATE

"""
initrep="""    result%temporal_acceptance_source = TX_TEMPORAL_MODEL_CERTIFICATE
    repro13_trace=''
    call get_environment_variable('TEMPORAL02_TRACE',repro13_trace,status=repro13_env_status)
    repro13_enabled = repro13_env_status == 0 .and. trim(repro13_trace) == '1'

"""
if init not in tail: raise SystemExit("R13 init seam missing")
tail=tail.replace(init,initrep,1)

solver="""      if (.not. outcome%solver_ok) then
        result%solver_rejections = result%solver_rejections + 1
"""
solverrep="""      if (.not. outcome%solver_ok) then
        if(repro13_enabled) write(*,'(*(g0))') 'TEMPORAL02_P1_ATTEMPT|RETRY_INDEX=',retry_index, &
             '|DT=',attempt_dt,'|REASON=SOLVER|SOLVER_OK=0|NONLINEAR=',outcome%nonlinear_iterations, &
             '|BACKTRACK=',outcome%backtracking_attempts,'|CERT_AVAILABLE=',outcome%temporal_certificate_available, &
             '|INDICATOR=',outcome%temporal_indicator
        result%solver_rejections = result%solver_rejections + 1
"""
if solver not in tail: raise SystemExit("R13 solver seam missing")
tail=tail.replace(solver,solverrep,1)

mass="""      if (.not. mass_ok) then
        result%mass_rejections = result%mass_rejections + 1
"""
massrep="""      if (.not. mass_ok) then
        if(repro13_enabled) write(*,'(*(g0))') 'TEMPORAL02_P1_ATTEMPT|RETRY_INDEX=',retry_index, &
             '|DT=',attempt_dt,'|REASON=MASS|SOLVER_OK=1|NONLINEAR=',outcome%nonlinear_iterations, &
             '|BACKTRACK=',outcome%backtracking_attempts,'|CERT_AVAILABLE=',outcome%temporal_certificate_available, &
             '|INDICATOR=',outcome%temporal_indicator,'|MASS_RESIDUAL=',mass_residual
        result%mass_rejections = result%mass_rejections + 1
"""
if mass not in tail: raise SystemExit("R13 mass seam missing")
tail=tail.replace(mass,massrep,1)

temp="""      if (.not. temporal_ok) then
        result%temporal_rejections = result%temporal_rejections + 1
"""
temprep="""      if (.not. temporal_ok) then
        if(repro13_enabled) write(*,'(*(g0))') 'TEMPORAL02_P1_ATTEMPT|RETRY_INDEX=',retry_index, &
             '|DT=',attempt_dt,'|REASON=TEMPORAL|SOLVER_OK=1|NONLINEAR=',outcome%nonlinear_iterations, &
             '|BACKTRACK=',outcome%backtracking_attempts,'|CERT_AVAILABLE=',outcome%temporal_certificate_available, &
             '|INDICATOR=',outcome%temporal_indicator,'|MASS_RESIDUAL=',mass_residual
        result%temporal_rejections = result%temporal_rejections + 1
"""
if temp not in tail: raise SystemExit("R13 temporal seam missing")
tail=tail.replace(temp,temprep,1)

accept="""      result%accepted_storage_start = storage0
"""
acceptrep="""      if(repro13_enabled) write(*,'(*(g0))') 'TEMPORAL02_P1_ATTEMPT|RETRY_INDEX=',retry_index, &
           '|DT=',attempt_dt,'|REASON=ACCEPTED|SOLVER_OK=1|NONLINEAR=',outcome%nonlinear_iterations, &
           '|BACKTRACK=',outcome%backtracking_attempts,'|CERT_AVAILABLE=',outcome%temporal_certificate_available, &
           '|INDICATOR=',outcome%temporal_indicator,'|MASS_RESIDUAL=',mass_residual
      result%accepted_storage_start = storage0
"""
if accept not in tail: raise SystemExit("R13 accept seam missing")
tail=tail.replace(accept,acceptrep,1)
p.write_text(head+tail)
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

# Make temporal head budget and case hydraulics configurable before initialize.
src=src.replace("  real(real64), parameter :: HEAD_BUDGET=1.0e-5_real64\n",
                "  real(real64), save :: HEAD_BUDGET=1.0e-5_real64\n",1)
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
"    p%max_iterations=16; p%max_backtracking=8; p%min_step_duration=1.0e-8_real64\n",
"    p%max_iterations=48; p%max_backtracking=16; p%min_step_duration=1.0e-10_real64\n",1)

src=src.replace(
"  public :: fgc44_predictor_run_diagnostics_c\n",
"  public :: fgc44_predictor_run_diagnostics_c\n"
"  public :: fgc44_approx04_configure_case_c, fgc44_approx04_p1b_state_c, fgc44_approx04_predictor_q_c\n"
"  public :: fgc44_repro02_observation_c\n"
"  public :: fgc44_temporal02_head_budget_c\n",1)
needle="contains\n\n"
insert="""contains

  integer(c_int) function fgc44_temporal02_head_budget_c(value) bind(C,name="fgc44_temporal02_head_budget_c")
    real(c_double), value, intent(in) :: value
    fgc44_temporal02_head_budget_c=1_c_int
    if(initialized)return
    if(.not.ieee_is_finite(real(value,real64)) .or. value<=0.0_c_double)return
    HEAD_BUDGET=real(value,real64)
    fgc44_temporal02_head_budget_c=0_c_int
  end function fgc44_temporal02_head_budget_c

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
src=src.replace("    type is(fmr_b110_physical_state_t)\n      if(.not.allocated(state%pressure_head)", &
                "    class is(fmr_b110_physical_state_t)\n      if(.not.allocated(state%pressure_head)",1)
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
material,h0_s,offset_s,budget_s=sys.argv[1:]
h0=float(h0_s); offset_cm=float(offset_s); budget=float(budget_s)
swap=Fgc44RealSwap(Path(os.environ["FGC44_SWAP_LIB"]))
cfg=swap.lib.fgc44_approx04_configure_case_c
cfg.restype=ctypes.c_int; cfg.argtypes=[ctypes.c_double]*7
tr,ts,alpha,nvg,ksat,lamb=MATERIALS[material]
if cfg(h0,tr,ts,alpha,nvg,ksat,lamb): raise RuntimeError("configure failed")
budgetfn=swap.lib.fgc44_temporal02_head_budget_c
budgetfn.restype=ctypes.c_int; budgetfn.argtypes=[ctypes.c_double]
if budgetfn(budget): raise RuntimeError("temporal budget configuration failed")
predfn=swap.lib.fgc44_approx04_predictor_q_c
predfn.restype=ctypes.c_int; predfn.argtypes=[ctypes.POINTER(ctypes.c_double)]
predictor_q=ctypes.c_double()
if predfn(ctypes.byref(predictor_q)): raise RuntimeError("predictor q failed")
_,_,href=swap.initialize_configured(1.0e-4,predictor_q.value)
os.environ["TEMPORAL02_TRACE"]="1"
q=ctypes.c_double()
status=int(swap.lib.fgc44_swap_trial_c(float(href+offset_cm/100.0),ctypes.byref(q)))
exchange=0.0; qresp=0.0; tangent=0.0; tangent_available=False; heads=[]; water=[]
if status==0:
    qresp,exchange,tangent,tangent_available=swap.last_trial_response()
    swap.commit_swap()
    statefn=swap.lib.fgc44_approx04_p1b_state_c
    statefn.restype=ctypes.c_int
    statefn.argtypes=[ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
    ha=(ctypes.c_double*4)(); wa=(ctypes.c_double*4)()
    if statefn(ha,wa): raise RuntimeError("P1 state snapshot failed")
    heads=list(ha); water=list(wa)

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
d.update(material=material,h0=h0,offset_cm=offset_cm,budget=budget,href=href,predictor_q=predictor_q.value,participant_status=status,q=q.value,qresp=qresp,exchange=exchange,tangent=tangent,tangent_available=tangent_available,heads=heads,water=water)
print("TEMPORAL02_P1_RAW|"+json.dumps(d,separators=(",",":")))
PY

COMMON=(-std=f2008 -ffree-line-length-none -O2 -fPIC -fopenmp)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  "$BUILD/lib/mod_transaction_reference.f90"
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
OUT="$BUILD/p1.txt"; : > "$OUT"
cases=("B01|wet|-10" "B01|mid|-75" "B12|wet|-10" "O05|wet|-10" "O14|wet|-10" "O14|mid|-75")
offsets=(-0.001 0.001)
budgets=(2e-4 5e-4 1e-3)
reps=3
for case_spec in "${cases[@]}"; do
  IFS='|' read -r material regime h0 <<< "$case_spec"
  for budget in "${budgets[@]}"; do
    for offset in "${offsets[@]}"; do
      for rep in $(seq 1 "$reps"); do
        raw="$(FGC44_SWAP_LIB="$BUILD/lib/libswap.so" python3 "$BUILD/py/bench.py" "$material" "$h0" "$offset" "$budget" 2>&1)" || { printf '%s\n' "$raw" >&2; fail "$material $regime $offset $budget"; }
        final="$(printf '%s\n' "$raw" | grep '^TEMPORAL02_P1_RAW|' | tail -1)"
        [[ -n "$final" ]] || fail "missing P1 record"
        printf '%s|REGIME=%s|REP=%s\n' "$final" "$regime" "$rep" >> "$OUT"
      done
    done
  done
done

python3 - "$OUT" <<'PY'
import collections,json,math,sys
groups=collections.defaultdict(list)
for line in open(sys.argv[1]):
    if not line.startswith("TEMPORAL02_P1_RAW|"): continue
    payload,tail=line.strip().split("|REGIME=",1)
    reg,rep=tail.split("|REP=",1)
    d=json.loads(payload.split("|",1)[1]); d["regime"]=reg; d["rep"]=int(rep)
    groups[(d["material"],reg,d["offset_cm"],d["budget"])].append(d)
if len(groups)!=36: raise SystemExit(f"expected 36 groups, got {len(groups)}")
for k,rs in groups.items():
    sig={(r["participant_status"],tuple(r["heads"]),tuple(r["water"]),r["qresp"],r["exchange"]) for r in rs}
    if len(rs)!=3 or len(sig)!=1: raise SystemExit(f"nondeterministic P1 state {k}")

maxdh=maxdt=maxq=maxex=0.0
compared=0
for mat,reg,off in sorted({(k[0],k[1],k[2]) for k in groups}):
    ref=groups[(mat,reg,off,1e-3)][0]
    if ref["participant_status"]!=0 or not ref["heads"]: raise SystemExit(f"missing full-step reference {(mat,reg,off)}")
    for budget in (2e-4,5e-4):
        r=groups[(mat,reg,off,budget)][0]
        if r["participant_status"]!=0:
            print(f"TEMPORAL02_P1_POINT|MATERIAL={mat}|REGIME={reg}|OFFSET_CM={off:.6f}|BUDGET_CM={budget:.1e}|PASS=FALSE")
            continue
        dh=max(abs(a-b) for a,b in zip(r["heads"],ref["heads"]))
        dt=max(abs(a-b) for a,b in zip(r["water"],ref["water"]))
        dq=abs(r["qresp"]-ref["qresp"])
        dex=abs(r["exchange"]-ref["exchange"])
        compared+=1; maxdh=max(maxdh,dh); maxdt=max(maxdt,dt); maxq=max(maxq,dq); maxex=max(maxex,dex)
        print(f"TEMPORAL02_P1_POINT|MATERIAL={mat}|REGIME={reg}|OFFSET_CM={off:.6f}|BUDGET_CM={budget:.1e}|PASS=TRUE"
              f"|MAX_DH_CM={dh:.17e}|MAX_DTHETA={dt:.17e}|ABS_DQ_MPS={dq:.17e}|ABS_DEXCHANGE_CM={dex:.17e}")
print(f"TEMPORAL02_P1_SUMMARY|COMPARED={compared}|MAX_DH_CM={maxdh:.17e}|MAX_DTHETA={maxdt:.17e}|MAX_ABS_DQ_MPS={maxq:.17e}|MAX_ABS_DEXCHANGE_CM={maxex:.17e}")
print("FPE_TEMPORAL02_P1=PASS")
PY
