#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-endpoint01-dynamic-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/lib" "$BUILD/py"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ENDPOINT01_FAIL $*" >&2; exit 1; }

mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads"
python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main
bindir=Path("$BUILD/modflow-bin")
downloads=Path("$BUILD/downloads")
run_main(bindir,owner="MODFLOW-ORG",repo="modflow6",release_id="6.8.0",
         subset={"mf6","libmf6.so"},downloads_dir=downloads,force=True,quiet=False)
PY
ARCHIVE="$BUILD/downloads/modflow6-6.8.0-linux.zip"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $ARCHIVE" | sha256sum -c - || fail "MODFLOW asset hash"
test -f "$BUILD/modflow-bin/libmf6.so" || fail "missing libmf6.so"


cp tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90 "$BUILD/lib/mod_fgc44_real_swap_c_bridge.f90"
cp src/runtime/mod_fmr_groundwater_swap_participant.f90 "$BUILD/lib/mod_fmr_groundwater_swap_participant.f90"
python3 - "$BUILD/lib/mod_fmr_groundwater_swap_participant.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
src=src.replace(
"    procedure, public :: tangent_cache_counts => fmr_swap_tangent_cache_counts\n",
"    procedure, public :: tangent_cache_counts => fmr_swap_tangent_cache_counts\n"
"    procedure, public :: temporal04_diagnostics => fmr_swap_temporal04_diagnostics\n"
"    procedure, public :: temporal05_mass => fmr_swap_temporal05_mass\n",1)
needle="end module mod_fmr_groundwater_swap_participant"
insert="""
  subroutine fmr_swap_temporal04_diagnostics(self,transaction_calls,accepted_substeps,attempts,retries, &
       solver_rejections,temporal_rejections,nonlinear_iterations,backtracking_attempts,max_temporal_indicator)
    class(fmr_groundwater_swap_participant_t), intent(in) :: self
    integer, intent(out) :: transaction_calls,accepted_substeps,attempts,retries
    integer, intent(out) :: solver_rejections,temporal_rejections,nonlinear_iterations,backtracking_attempts
    real(real64), intent(out) :: max_temporal_indicator
    transaction_calls=self%diagnostics%transaction_calls
    accepted_substeps=self%diagnostics%accepted_substeps
    attempts=self%diagnostics%attempts
    retries=self%diagnostics%retries
    solver_rejections=self%diagnostics%solver_rejections
    temporal_rejections=self%diagnostics%temporal_rejections
    nonlinear_iterations=self%diagnostics%nonlinear_iterations
    backtracking_attempts=self%diagnostics%backtracking_attempts
    max_temporal_indicator=self%diagnostics%max_temporal_indicator
  end subroutine fmr_swap_temporal04_diagnostics

  subroutine fmr_swap_temporal05_mass(self,complete,residual)
    class(fmr_groundwater_swap_participant_t), intent(in) :: self
    logical, intent(out) :: complete
    real(real64), intent(out) :: residual
    complete=self%trial_result%mass%complete
    residual=self%trial_result%mass%residual
  end subroutine fmr_swap_temporal05_mass

"""
if needle not in src: raise SystemExit("participant end seam missing")
src=src.replace(needle,insert+needle,1)
p.write_text(src)
PY
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
"       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state, &\n"
"       fmr_new_b110_committed_state\n",1)

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
"  public :: fgc44_temporal03_dynamic_origin_c, fgc44_temporal03_oracle_c, fgc44_temporal04_budget_c\n"
"  public :: fgc44_temporal04_diagnostics_c, fgc44_temporal05_mass_c\n"
"  public :: fgc44_temporal06_tangent_cache_c, fgc44_temporal06_tangent_counts_c\n",1)
needle="contains\n\n"
insert="""contains

  integer(c_int) function fgc44_temporal06_tangent_cache_c(enabled) bind(C,name="fgc44_temporal06_tangent_cache_c")
    integer(c_int), value, intent(in) :: enabled
    integer :: status
    fgc44_temporal06_tangent_cache_c=1_c_int
    if(.not.initialized)return
    call participant%configure_tangent_cache(enabled/=0_c_int,0.005_real64,8,status)
    if(status/=0)return
    fgc44_temporal06_tangent_cache_c=0_c_int
  end function fgc44_temporal06_tangent_cache_c

  integer(c_int) function fgc44_temporal06_tangent_counts_c(fresh,reuse) bind(C,name="fgc44_temporal06_tangent_counts_c")
    integer(c_int), intent(out) :: fresh,reuse
    integer :: f,r
    call participant%tangent_cache_counts(f,r)
    fresh=int(f,c_int); reuse=int(r,c_int)
    fgc44_temporal06_tangent_counts_c=0_c_int
  end function fgc44_temporal06_tangent_counts_c

  integer(c_int) function fgc44_temporal05_mass_c(complete,residual) bind(C,name="fgc44_temporal05_mass_c")
    integer(c_int), intent(out) :: complete
    real(c_double), intent(out) :: residual
    logical :: ok
    real(real64) :: r
    call participant%temporal05_mass(ok,r)
    complete=merge(1_c_int,0_c_int,ok)
    residual=real(r,c_double)
    fgc44_temporal05_mass_c=0_c_int
  end function fgc44_temporal05_mass_c

  integer(c_int) function fgc44_temporal04_diagnostics_c(transaction_calls,accepted_substeps,attempts,retries, &
       solver_rejections,temporal_rejections,nonlinear_iterations,backtracking_attempts,max_temporal_indicator) &
       bind(C,name="fgc44_temporal04_diagnostics_c")
    integer(c_int), intent(out) :: transaction_calls,accepted_substeps,attempts,retries
    integer(c_int), intent(out) :: solver_rejections,temporal_rejections,nonlinear_iterations,backtracking_attempts
    real(c_double), intent(out) :: max_temporal_indicator
    integer :: tc,asub,att,ret,srej,trej,nli,bta
    real(real64) :: mt
    call participant%temporal04_diagnostics(tc,asub,att,ret,srej,trej,nli,bta,mt)
    transaction_calls=int(tc,c_int); accepted_substeps=int(asub,c_int); attempts=int(att,c_int); retries=int(ret,c_int)
    solver_rejections=int(srej,c_int); temporal_rejections=int(trej,c_int)
    nonlinear_iterations=int(nli,c_int); backtracking_attempts=int(bta,c_int)
    max_temporal_indicator=real(mt,c_double)
    fgc44_temporal04_diagnostics_c=0_c_int
  end function fgc44_temporal04_diagnostics_c

  integer(c_int) function fgc44_temporal04_budget_c(value) bind(C,name="fgc44_temporal04_budget_c")
    real(c_double), value, intent(in) :: value
    fgc44_temporal04_budget_c=1_c_int
    if(.not.initialized)return
    if(.not.ieee_is_finite(real(value,real64)) .or. value<=0.0_c_double)return
    corrector_config%model_temporal_indicator_budget_available=.true.
    corrector_config%model_temporal_indicator_budget=real(value,real64)
    fgc44_temporal04_budget_c=0_c_int
  end function fgc44_temporal04_budget_c

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

  integer(c_int) function fgc44_temporal03_oracle_c(prescribed_head_m,nsub,heads,theta,bottom_exchange, &
       terminal_flux,mass_residual,max_abs_step_residual) bind(C,name="fgc44_temporal03_oracle_c")
    real(c_double), value, intent(in) :: prescribed_head_m
    integer(c_int), value, intent(in) :: nsub
    real(c_double), intent(out) :: heads(numnod),theta(numnod)
    real(c_double), intent(out) :: bottom_exchange,terminal_flux,mass_residual,max_abs_step_residual
    class(transaction_state_t), allocatable :: snap,final_snap
    class(canonical_forcing_t), allocatable :: generic_forcing
    type(fmr_b110_physical_state_t) :: base
    type(kernel_committed_state_t) :: plain
    type(fmr_serialized_reference_backend_t) :: oracle_backend
    type(fmr_template_t) :: floor_template
    type(fmr_b110_physical_forcing_t) :: oracle_forcing
    type(fmr_b110_physical_parameters_t) :: floor_parameters
    type(kernel_reference_floor_result_t) :: r
    type(kernel_reference_floor_candidate_t) :: c
    type(kernel_diagnostics_t) :: d
    real(real64) :: dt,t0,t1,exchange_sum,residual_sum,max_step_resid
    logical :: available,ok,did_commit
    integer :: i,status

    fgc44_temporal03_oracle_c=1_c_int
    heads=0.0_c_double; theta=0.0_c_double; bottom_exchange=0.0_c_double
    terminal_flux=0.0_c_double; mass_residual=0.0_c_double; max_abs_step_residual=0.0_c_double
    if(.not.initialized .or. nsub<=0_c_int)return
    if(.not.ieee_is_finite(real(prescribed_head_m,real64)))return
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
    if(status/=GW_SWAP_FORCING_OK .or. .not.allocated(generic_forcing))then
      write(*,'(*(g0))') 'ENDPOINT01_FAILPOINT|STAGE=MATERIALIZE|STATUS=',status
      return
    end if
    select type(f=>generic_forcing)
    type is(fmr_b110_physical_forcing_t)
      oracle_forcing=f
    class default
      return
    end select

    call oracle_backend%initialize(top)
    dt=(window%t1-window%t0)/real(nsub,real64)
    exchange_sum=0.0_real64; residual_sum=0.0_real64; max_step_resid=0.0_real64
    do i=1,int(nsub)
      t0=window%t0+real(i-1,real64)*dt
      t1=window%t0+real(i,real64)*dt
      floor_parameters=corrector_parameters
      floor_parameters%compartment_balance_tolerance=max(1.0e-12_real64,2.8e-16_real64/dt)
      floor_parameters%total_balance_tolerance=max(1.0e-12_real64,2.8e-16_real64/dt)
      call oracle_backend%run_reference_floor_sample(column,floor_template,floor_parameters,plain,oracle_forcing, &
           t0,t1,1.0e-12_real64,r,c,d)
      if(.not.r%sample_valid .or. .not.r%mass%complete .or. .not.c%ready())then
        write(*,'(*(g0))') 'ENDPOINT01_FAILPOINT|STAGE=FLOOR|I=',i,'|STATUS=',r%status, &
             '|VALID=',r%sample_valid,'|MASS=',r%mass%complete,'|READY=',c%ready()
        return
      end if
      if(.not.r%bottom_interface_exchange_available)then
        write(*,'(*(g0))') 'ENDPOINT01_FAILPOINT|STAGE=EXCHANGE|I=',i
        return
      end if
      exchange_sum=exchange_sum+r%bottom_outward_exchange_native
      residual_sum=residual_sum+r%mass%residual
      max_step_resid=max(max_step_resid,abs(r%mass%residual))
      terminal_flux=r%terminal_bottom_outward_flux_native
      call oracle_backend%commit_reference_floor_candidate(plain,c,d,did_commit,status)
      if(.not.did_commit .or. status/=0)then
        write(*,'(*(g0))') 'ENDPOINT01_FAILPOINT|STAGE=COMMIT|I=',i,'|DID=',did_commit,'|STATUS=',status
        return
      end if
    end do

    call plain%snapshot(final_snap,available)
    if(.not.available .or. .not.allocated(final_snap))return
    select type(p=>final_snap)
    class is(fmr_b110_physical_state_t)
      if(.not.allocated(p%pressure_head) .or. .not.allocated(p%water_content))return
      heads=p%pressure_head; theta=p%water_content
    class default
      return
    end select
    bottom_exchange=exchange_sum; mass_residual=residual_sum; max_abs_step_residual=max_step_resid
    fgc44_temporal03_oracle_c=0_c_int
  end function fgc44_temporal03_oracle_c

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
    class is(fmr_b110_physical_state_t)
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
material,h0_s,imb_s=sys.argv[1:]
h0=float(h0_s); imbalance=float(imb_s); dt=1e-4
swap=Fgc44RealSwap(Path(os.environ["FGC44_SWAP_LIB"]))
cfg=swap.lib.fgc44_approx04_configure_case_c
cfg.restype=ctypes.c_int; cfg.argtypes=[ctypes.c_double]*7
tr,ts,alpha,nvg,ksat,lamb=MATERIALS[material]
if cfg(h0,tr,ts,alpha,nvg,ksat,lamb): raise RuntimeError("configure failed")
predfn=swap.lib.fgc44_approx04_predictor_q_c
predfn.restype=ctypes.c_int; predfn.argtypes=[ctypes.POINTER(ctypes.c_double)]
predictor_q=ctypes.c_double()
if predfn(ctypes.byref(predictor_q)): raise RuntimeError("predictor q failed")
swap.initialize_configured(dt,predictor_q.value)
dyn=swap.lib.fgc44_temporal03_dynamic_origin_c
dyn.restype=ctypes.c_int
dyn.argtypes=[ctypes.c_double,*([ctypes.POINTER(ctypes.c_double)]*3)]
rate=ctypes.c_double(); origin_mass=ctypes.c_double(); origin_head=ctypes.c_double()
if dyn(imbalance,ctypes.byref(rate),ctypes.byref(origin_mass),ctypes.byref(origin_head)):
    raise RuntimeError("dynamic origin failed")
cachefn=swap.lib.fgc44_temporal06_tangent_cache_c
cachefn.restype=ctypes.c_int; cachefn.argtypes=[ctypes.c_int]
if cachefn(0): raise RuntimeError("cache disable failed")
bfn=swap.lib.fgc44_temporal04_budget_c
bfn.restype=ctypes.c_int; bfn.argtypes=[ctypes.c_double]
budget=max(1e-5,0.65*dt*rate.value)
if bfn(budget): raise RuntimeError("budget set failed")
dfn=swap.lib.fgc44_temporal04_diagnostics_c
dfn.restype=ctypes.c_int
dfn.argtypes=[*([ctypes.POINTER(ctypes.c_int)]*8),ctypes.POINTER(ctypes.c_double)]
def run(head):
    q=ctypes.c_double(); status=int(swap.lib.fgc44_swap_trial_c(head,ctypes.byref(q)))
    di=[ctypes.c_int() for _ in range(8)]; mt=ctypes.c_double()
    if dfn(*[ctypes.byref(x) for x in di],ctypes.byref(mt)): raise RuntimeError("diag failed")
    out={"status":status,"steps":di[1].value,"attempts":di[2].value,"retries":di[3].value,
         "solver_rejections":di[4].value,"temporal_rejections":di[5].value}
    if status==0:
        qresp,exchange,tangent,available=swap.last_trial_response()
        if not available: raise RuntimeError("tangent unavailable")
        out.update({"q":qresp,"exchange":exchange,"tangent":tangent})
        swap.discard()
    return out
center=run(origin_head.value)
deltas=[-0.001,0.001,-0.01,0.01,-0.05,0.05,-0.10,0.10]
probes=[]
for dcm in deltas:
    actual=run(origin_head.value+dcm/100.0)
    pred=None; abs_err=None; rel_err=None
    if center["status"]==0 and actual["status"]==0:
        pred=center["q"]+center["tangent"]*(dcm/100.0)
        abs_err=abs(actual["q"]-pred)
        rel_err=abs_err/max(abs(actual["q"]),1e-30)
    probes.append({"delta_cm":dcm,"actual":actual,"pred_q":pred,"abs_err":abs_err,"rel_err":rel_err})
print("TEMPORAL07_P0_RAW|"+json.dumps({
 "material":material,"h0_cm":h0,"imbalance":imbalance,"origin_head_m":origin_head.value,
 "hprev_cm_per_day":rate.value,"budget_cm":budget,"origin_mass_residual":origin_mass.value,
 "center":center,"probes":probes},separators=(",",":")))
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
  "$BUILD/lib/mod_fmr_groundwater_swap_participant.f90"
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

export PYTHONPATH="$ROOT/src/adapter:$ROOT/tests/fgc/support"
cat > "$BUILD/py/endpoint.py" <<'PY'
from __future__ import annotations
import ctypes, math, os, sys
from pathlib import Path

ROOT=Path(os.environ["ENDPOINT01_REPO_ROOT"])
sys.path.insert(0,str(ROOT/"src"/"adapter"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"/"support"))
sys.path.insert(0,str(ROOT/"tests"/"fgc"))

import test_fgc44_real_swap_modflow_end_to_end as base
from fgc44_real_swap_ctypes import Fgc44RealSwap

base.CLOSEOUT_ONECELL=True
base.CLOSEOUT_COMPATIBLE_SOLVER=True

LIBMF6=Path(os.environ["LIBMF6"]).resolve()
SWAPLIB=Path(os.environ["FGC44_SWAP_LIB"]).resolve()
DT=1.0e-4
MATERIAL=(0.01,0.393878,0.003288,1.616573,2.495984,0.514012)

PRODUCTION={
    0.50: {
        "head": -0.75000062586460614,
        "q": 9.9736588659561821e-08,
    },
    0.65: {
        "head": -0.75000062715641813,
        "q": 9.9710423475088018e-08,
    },
}

def require(x,msg):
    if not x:
        raise AssertionError(msg)

def setup_swap(coeff:float):
    swap=Fgc44RealSwap(SWAPLIB)
    cfg=swap.lib.fgc44_approx04_configure_case_c
    cfg.restype=ctypes.c_int
    cfg.argtypes=[ctypes.c_double]*7
    tr,ts,alpha,nvg,ksat,lamb=MATERIAL
    require(cfg(-75.0,tr,ts,alpha,nvg,ksat,lamb)==0,"case configure failed")
    predfn=swap.lib.fgc44_approx04_predictor_q_c
    predfn.restype=ctypes.c_int
    predfn.argtypes=[ctypes.POINTER(ctypes.c_double)]
    predictor_q=ctypes.c_double()
    require(predfn(ctypes.byref(predictor_q))==0,"predictor q failed")
    swap.initialize_configured(DT,predictor_q.value)
    dyn=swap.lib.fgc44_temporal03_dynamic_origin_c
    dyn.restype=ctypes.c_int
    dyn.argtypes=[ctypes.c_double,*([ctypes.POINTER(ctypes.c_double)]*3)]
    rate=ctypes.c_double(); mass=ctypes.c_double(); origin_head=ctypes.c_double()
    require(dyn(-0.10,ctypes.byref(rate),ctypes.byref(mass),ctypes.byref(origin_head))==0,
            "dynamic origin failed")
    bfn=swap.lib.fgc44_temporal04_budget_c
    bfn.restype=ctypes.c_int; bfn.argtypes=[ctypes.c_double]
    budget=max(1e-5,coeff*DT*rate.value)
    require(bfn(budget)==0,"budget failed")
    cachefn=swap.lib.fgc44_temporal06_tangent_cache_c
    cachefn.restype=ctypes.c_int; cachefn.argtypes=[ctypes.c_int]
    require(cachefn(0)==0,"cache disable failed")
    origin_state=swap.state()
    require(origin_state[0]==0 and abs(origin_state[1]-DT)<=1e-14 and origin_state[2:]==(0,0.0),
            "bad dynamic origin state")
    return swap,origin_head.value,origin_state,budget

def swap_q(swap,origin_state,head):
    q=swap.trial(head)
    require(math.isfinite(q),"nonfinite SWAP q")
    swap.discard()
    require(swap.state()==origin_state,"SWAP oracle probe mutated origin")
    return q

def gw_head(href,q):
    h,qgw,iters=base.solve_closeout_constant_flux(LIBMF6,SWAPLIB,href,q)
    require(math.isfinite(h) and math.isfinite(qgw),"nonfinite groundwater oracle")
    require(abs(qgw-q)<=64*sys.float_info.epsilon*max(1.0,abs(q)),
            "constant-flux groundwater oracle changed imposed q")
    return h,iters

def direct_residual(swap,origin_state,href,q):
    h,iters=gw_head(href,q)
    qs=swap_q(swap,origin_state,h)
    return qs-q,h,qs,iters

def bracket_q(swap,origin_state,href,qcenter):
    half=max(2.0e-8,0.25*abs(qcenter))
    lo=qcenter-half; hi=qcenter+half
    rlo,*_=direct_residual(swap,origin_state,href,lo)
    rhi,*_=direct_residual(swap,origin_state,href,hi)
    expansions=0
    while not (rlo==0.0 or rhi==0.0 or rlo*rhi<0.0) and expansions<6:
        half*=2.0
        lo=qcenter-half; hi=qcenter+half
        rlo,*_=direct_residual(swap,origin_state,href,lo)
        rhi,*_=direct_residual(swap,origin_state,href,hi)
        expansions+=1
    require(rlo==0.0 or rhi==0.0 or rlo*rhi<0.0,
            "direct q-space endpoint not bracketed")
    return lo,hi,rlo,rhi,half,expansions

def direct_endpoint(swap,origin_state,href):
    qcenter=swap_q(swap,origin_state,href)
    lo,hi,rlo,rhi,half,expansions=bracket_q(swap,origin_state,href,qcenter)
    if rlo==0.0:
        qroot=lo
    elif rhi==0.0:
        qroot=hi
    else:
        qroot=0.5*(lo+hi)
        for _ in range(80):
            qroot=0.5*(lo+hi)
            r,h,qs,iters=direct_residual(swap,origin_state,href,qroot)
            if abs(r)<=1.0e-15:
                return qroot,h,r,qs,half,expansions
            if rlo*r<=0.0:
                hi=qroot; rhi=r
            else:
                lo=qroot; rlo=r
        r,h,qs,iters=direct_residual(swap,origin_state,href,qroot)
        require(abs(r)<=1.0e-15,"direct endpoint did not meet frozen residual gate")
        return qroot,h,r,qs,half,expansions
    r,h,qs,iters=direct_residual(swap,origin_state,href,qroot)
    return qroot,h,r,qs,half,expansions

def q_for_head(href,target_head,qguess):
    half=max(2.0e-8,0.25*abs(qguess))
    def f(q):
        h,_=gw_head(href,q)
        return h-target_head,h
    lo=qguess-half; hi=qguess+half
    flo,_=f(lo); fhi,_=f(hi)
    expansions=0
    while not (flo==0.0 or fhi==0.0 or flo*fhi<0.0) and expansions<6:
        half*=2.0; lo=qguess-half; hi=qguess+half
        flo,_=f(lo); fhi,_=f(hi); expansions+=1
    require(flo==0.0 or fhi==0.0 or flo*fhi<0.0,"target head not bracketed in q")
    if flo==0.0: return lo
    if fhi==0.0: return hi
    q=0.5*(lo+hi)
    for _ in range(80):
        q=0.5*(lo+hi)
        fq,_=f(q)
        if abs(fq)<=1.0e-14:
            return q
        if flo*fq<=0.0:
            hi=q; fhi=fq
        else:
            lo=q; flo=fq
    return q

def curvature(href):
    qs=[-1.5e-7,-1.0e-7,-5e-8,-2e-8,0.0,2e-8,5e-8,1.0e-7,1.5e-7]
    pts=[]
    for q in qs:
        h,it=gw_head(href,q)
        pts.append((q,h,it))
        print(f"ENDPOINT01_GW_LADDER|Q={q:.17e}|H={h:.17e}|ITERS={it}")
    # Historical local q(H) fit from the three central points.
    import numpy as np
    central=[p for p in pts if p[0] in (-2e-8,0.0,2e-8)]
    hs=np.asarray([p[1] for p in central])
    fs=np.asarray([p[0] for p in central])
    slope,intercept=np.polyfit(hs,fs,1)
    errs=[]
    for q,h,_ in pts:
        qfit=slope*h+intercept
        errs.append(abs(qfit-q))
        print(f"ENDPOINT01_GW_FIT_POINT|Q={q:.17e}|H={h:.17e}|QFIT={qfit:.17e}|ABS_ERR={abs(qfit-q):.17e}")
    print(f"ENDPOINT01_GW_LOCAL_FIT_SLOPE={slope:.17e}")
    print(f"ENDPOINT01_GW_LOCAL_FIT_MAX_LADDER_ABS_ERR={max(errs):.17e}")

def run_coeff(coeff:float):
    swap,href,state,budget=setup_swap(coeff)
    qroot,hroot,rroot,qsroot,half,exp=direct_endpoint(swap,state,href)
    require(abs(rroot)<=1.0e-15,"direct root residual gate failed")
    prod=PRODUCTION[coeff]
    qdirect=q_for_head(href,prod["head"],prod["q"])
    qswap_prod=swap_q(swap,state,prod["head"])
    direct_prod_res=qswap_prod-qdirect
    head_err=prod["head"]-hroot
    print(f"ENDPOINT01_POLICY|C={coeff:.2f}|BUDGET_CM={budget:.17e}|QROOT={qroot:.17e}|HROOT={hroot:.17e}|ROOT_RES={rroot:.17e}|BRACKET_HALF={half:.17e}|EXPANSIONS={exp}")
    print(f"ENDPOINT01_PRODUCTION_COMPARE|C={coeff:.2f}|HPROD={prod['head']:.17e}|HDIRECT={hroot:.17e}|HEAD_ERR={head_err:.17e}|QSWAP_PROD={qswap_prod:.17e}|QGW_DIRECT_AT_HPROD={qdirect:.17e}|DIRECT_RES_AT_HPROD={direct_prod_res:.17e}")
    require(abs(head_err)<=5.0e-10,"production/direct endpoint head gate failed")
    require(abs(direct_prod_res)<=1.0e-15,"direct physical residual at production endpoint failed")
    print(f"ENDPOINT01_POLICY_C{int(round(coeff*100)):03d}=PASS")
    return href

href=run_coeff(0.50)
href2=run_coeff(0.65)
require(abs(href-href2)<=1e-14,"policy origins differ")
curvature(href)
print("FPE_ENDPOINT01_DYNAMIC_DIRECT_AUTHORITY=PASS")
PY

ENDPOINT01_REPO_ROOT="$ROOT" FGC44_CLOSEOUT_ONECELL=1 FGC44_CLOSEOUT_COMPATIBLE_SOLVER=1 \
LIBMF6="$BUILD/modflow-bin/libmf6.so" FGC44_SWAP_LIB="$BUILD/lib/libswap.so" \
python3 "$BUILD/py/endpoint.py" | tee "$BUILD/endpoint.txt"

for marker in \
  'ENDPOINT01_POLICY_C050=PASS' \
  'ENDPOINT01_POLICY_C065=PASS' \
  'FPE_ENDPOINT01_DYNAMIC_DIRECT_AUTHORITY=PASS'; do
  grep -Fq "$marker" "$BUILD/endpoint.txt" || fail "missing marker $marker"
done
echo 'FPE_ENDPOINT01_P0_P2=PASS'
