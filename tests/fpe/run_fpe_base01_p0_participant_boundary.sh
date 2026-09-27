#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-solve01-p2b-${GITHUB_RUN_ID:-local}-$"
HEADCALC_SOURCE="${BASE01_HEADCALC_SOURCE:-src/legacy/b1_10_port/headcalc.f90}"
LEGACY_BINDING_SOURCE="${BASE01_LEGACY_BINDING_SOURCE:-src/adapter/mod_reference_richards_legacy_binding.f90}"
TEST_SCRIPT="${BASE01_TEST_SCRIPT:-tests/fpe/test_fpe_base01_p0_participant_boundary.py}"
TEMPORAL_INDICATOR_SOURCE="${BASE01_TEMPORAL_INDICATOR_SOURCE:-src/solver/mod_reference_richards_temporal_indicator.f90}"
EXTRA_SOURCE="${BASE01_EXTRA_SOURCE:-}"
PRE_SOURCE="${BASE01_PRE_SOURCE:-}"
TRANSACTION_SOURCE="${BASE01_TRANSACTION_SOURCE:-src/transaction/mod_transaction_reference.f90}"
CANONICAL_RUNTIME_SOURCE="${BASE01_CANONICAL_RUNTIME_SOURCE:-src/runtime/mod_canonical_interval_runtime.f90}"
KERNEL_SOURCE="${BASE01_KERNEL_SOURCE:-src/kernel/mod_kernel_transactions.f90}"
BACKEND_SOURCE="${BASE01_BACKEND_SOURCE:-src/runtime/mod_fmr_serialized_reference_backend.f90}"
PARTICIPANT_SOURCE="${BASE01_PARTICIPANT_SOURCE:-src/runtime/mod_fmr_groundwater_swap_participant.f90}"
BRIDGE_SOURCE="${BASE01_BRIDGE_SOURCE:-tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90}"
RAW_PREFIX="${BASE01_RAW_PREFIX:-BASE01_P0_RAW}"
export RAW_PREFIX
mkdir -p "$BUILD/lib" "$BUILD/py"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "SOLVE01_P2B_FAIL $*" >&2; exit 1; }

python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main
bindir=Path("$BUILD/modflow-bin")
downloads=Path("$BUILD/downloads")
bindir.mkdir(parents=True,exist_ok=True)
downloads.mkdir(parents=True,exist_ok=True)
run_main(bindir,owner="MODFLOW-ORG",repo="modflow6",release_id="6.8.0",
         subset={"mf6","libmf6.so"},downloads_dir=downloads,force=True,quiet=False)
PY
ARCHIVE="$BUILD/downloads/modflow6-6.8.0-linux.zip"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $ARCHIVE" | sha256sum -c - || fail "MODFLOW asset hash"
test -f "$BUILD/modflow-bin/libmf6.so" || fail "missing libmf6.so"

cp "$BRIDGE_SOURCE" "$BUILD/lib/mod_fgc44_real_swap_c_bridge.f90"
cp "$PARTICIPANT_SOURCE" "$BUILD/lib/mod_fmr_groundwater_swap_participant.f90"
cp "$BACKEND_SOURCE" "$BUILD/lib/mod_fmr_serialized_reference_backend.f90"
python3 - "$BUILD/lib/mod_fmr_serialized_reference_backend.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
old="""    request%numerical%compartment_balance_tolerance = self%compartment_balance_tolerance
    request%numerical%total_balance_tolerance = self%total_balance_tolerance
"""
new="""    request%numerical%compartment_balance_tolerance = max(self%compartment_balance_tolerance, 2.8e-16_real64 / step_duration)
    request%numerical%total_balance_tolerance = max(self%total_balance_tolerance, 2.8e-16_real64 / step_duration)
"""
if old in src:
    src=src.replace(old,new,1)
elif "FMR_REFERENCE_BALANCE_FLOOR_DEPTH_CM / step_duration" not in src:
    raise SystemExit("BALTOL02 authority seam missing")
p.write_text(src)
PY
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

python3 - "$BUILD/lib/mod_fmr_groundwater_swap_participant.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()

field="""    real(real64) :: tangent_cache_t1 = 0.0_real64
"""
field_rep=field+"""    integer(int64) :: base01_forcing_ticks = 0_int64
    integer(int64) :: base01_backend_ticks = 0_int64
    integer :: base01_trial_calls = 0
"""
if field not in src: raise SystemExit("BASE01 participant field seam missing")
src=src.replace(field,field_rep,1)

proc="""    procedure, public :: tangent_cache_counts => fmr_swap_tangent_cache_counts
"""
proc_rep=proc+"""    procedure, public :: base01_reset_timing => fmr_swap_base01_reset_timing
    procedure, public :: base01_timing => fmr_swap_base01_timing
"""
if proc not in src: raise SystemExit("BASE01 participant procedure seam missing")
src=src.replace(proc,proc_rep,1)

decl="""    integer :: forcing_status, interface_status
    logical :: refresh_tangent
"""
decl_rep="""    integer :: forcing_status, interface_status
    integer(int64) :: base01_c0, base01_c1
    logical :: refresh_tangent
"""
if decl not in src: raise SystemExit("BASE01 participant declaration seam missing")
src=src.replace(decl,decl_rep,1)

force="""    call materializer%materialize(prescribed_head_m, datum, forcing, forcing_status)
"""
force_rep="""    call system_clock(base01_c0)
    call materializer%materialize(prescribed_head_m, datum, forcing, forcing_status)
    call system_clock(base01_c1)
    self%base01_forcing_ticks = self%base01_forcing_ticks + max(0_int64, base01_c1-base01_c0)
"""
if force not in src: raise SystemExit("BASE01 forcing timing seam missing")
src=src.replace(force,force_rep,1)

backend="""      call backend%run_trial(column, template, parameters, committed, typed_forcing, trial_numerical, &
           window%t0, window%t1, self%origin_checkpoint, self%trial_result, self%candidate, self%diagnostics, &
           trusted_prepared_parameters=trusted_prepared_parameters)
"""
backend_rep="""      call system_clock(base01_c0)
      call backend%run_trial(column, template, parameters, committed, typed_forcing, trial_numerical, &
           window%t0, window%t1, self%origin_checkpoint, self%trial_result, self%candidate, self%diagnostics, &
           trusted_prepared_parameters=trusted_prepared_parameters)
      call system_clock(base01_c1)
      self%base01_backend_ticks = self%base01_backend_ticks + max(0_int64, base01_c1-base01_c0)
      self%base01_trial_calls = self%base01_trial_calls + 1
"""
if backend not in src: raise SystemExit("BASE01 backend timing seam missing")
src=src.replace(backend,backend_rep,1)

needle="end module mod_fmr_groundwater_swap_participant"
insert="""
  subroutine fmr_swap_base01_reset_timing(self)
    class(fmr_groundwater_swap_participant_t), intent(inout) :: self
    self%base01_forcing_ticks = 0_int64
    self%base01_backend_ticks = 0_int64
    self%base01_trial_calls = 0
  end subroutine fmr_swap_base01_reset_timing

  subroutine fmr_swap_base01_timing(self, forcing_seconds, backend_seconds, calls)
    class(fmr_groundwater_swap_participant_t), intent(in) :: self
    real(real64), intent(out) :: forcing_seconds, backend_seconds
    integer, intent(out) :: calls
    integer(int64) :: rate
    call system_clock(count_rate=rate)
    forcing_seconds = 0.0_real64
    backend_seconds = 0.0_real64
    if (rate > 0_int64) then
      forcing_seconds = real(self%base01_forcing_ticks,real64)/real(rate,real64)
      backend_seconds = real(self%base01_backend_ticks,real64)/real(rate,real64)
    end if
    calls = self%base01_trial_calls
  end subroutine fmr_swap_base01_timing

"""
if needle not in src: raise SystemExit("BASE01 participant end seam missing")
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
      write(*,'(*(g0))') 'SOLVE01_P2B_FAILPOINT|STAGE=MATERIALIZE|STATUS=',status
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
        write(*,'(*(g0))') 'SOLVE01_P2B_FAILPOINT|STAGE=FLOOR|I=',i,'|STATUS=',r%status, &
             '|VALID=',r%sample_valid,'|MASS=',r%mass%complete,'|READY=',c%ready()
        return
      end if
      if(.not.r%bottom_interface_exchange_available)then
        write(*,'(*(g0))') 'SOLVE01_P2B_FAILPOINT|STAGE=EXCHANGE|I=',i
        return
      end if
      exchange_sum=exchange_sum+r%bottom_outward_exchange_native
      residual_sum=residual_sum+r%mass%residual
      max_step_resid=max(max_step_resid,abs(r%mass%residual))
      terminal_flux=r%terminal_bottom_outward_flux_native
      call oracle_backend%commit_reference_floor_candidate(plain,c,d,did_commit,status)
      if(.not.did_commit .or. status/=0)then
        write(*,'(*(g0))') 'SOLVE01_P2B_FAILPOINT|STAGE=COMMIT|I=',i,'|DID=',did_commit,'|STATUS=',status
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


python3 - "$BUILD/lib/mod_fgc44_real_swap_c_bridge.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()

public="""  public :: fgc44_temporal06_tangent_cache_c, fgc44_temporal06_tangent_counts_c
"""
public_rep=public+"""  public :: fgc44_base01_timing_reset_c, fgc44_base01_timing_c
"""
if public not in src: raise SystemExit("BASE01 bridge public seam missing")
src=src.replace(public,public_rep,1)

needle="contains\n\n"
insert="""contains

  integer(c_int) function fgc44_base01_timing_reset_c() bind(C,name="fgc44_base01_timing_reset_c")
    fgc44_base01_timing_reset_c=1_c_int
    if(.not.initialized)return
    call participant%base01_reset_timing()
    fgc44_base01_timing_reset_c=0_c_int
  end function fgc44_base01_timing_reset_c

  integer(c_int) function fgc44_base01_timing_c(forcing_seconds,backend_seconds,calls) &
       bind(C,name="fgc44_base01_timing_c")
    real(c_double), intent(out) :: forcing_seconds,backend_seconds
    integer(c_int), intent(out) :: calls
    real(real64) :: fs,bs
    integer :: n
    fgc44_base01_timing_c=1_c_int
    forcing_seconds=0.0_c_double; backend_seconds=0.0_c_double; calls=0_c_int
    if(.not.initialized)return
    call participant%base01_timing(fs,bs,n)
    forcing_seconds=real(fs,c_double); backend_seconds=real(bs,c_double); calls=int(n,c_int)
    fgc44_base01_timing_c=0_c_int
  end function fgc44_base01_timing_c

"""
if needle not in src: raise SystemExit("BASE01 bridge contains seam missing")
src=src.replace(needle,insert,1)
p.write_text(src)
PY

cat > "$BUILD/py/bench.py" <<'PY'
import ctypes,json,os,sys,time
from pathlib import Path
sys.path.insert(0,str(Path("tests/fgc/support").resolve()))
from fgc44_real_swap_ctypes import Fgc44RealSwap

MATERIALS={
"B01":(0.02,0.427494,0.021659,1.734737,31.225016,0.98087),
"B12":(0.01,0.529749,0.016562,1.090671,2.245895,-4.493581),
"O05":(0.01,0.336701,0.030304,2.887502,17.418504,0.0736),
"O14":(0.01,0.393878,0.003288,1.616573,2.495984,0.514012),
}
material,h0_s,imb_s,mode,nseq_s=sys.argv[1:]
h0=float(h0_s); imbalance=float(imb_s); nseq=int(nseq_s); dt=1e-4
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

# Current TEMPORAL08 effective history-aware budget on the captured origin.
budget=max(1e-5,0.65*dt*rate.value)
bfn=swap.lib.fgc44_temporal04_budget_c
bfn.restype=ctypes.c_int; bfn.argtypes=[ctypes.c_double]
if bfn(budget): raise RuntimeError("budget set failed")

cfn=swap.lib.fgc44_temporal06_tangent_cache_c
cfn.restype=ctypes.c_int; cfn.argtypes=[ctypes.c_int]
if cfn(0): raise RuntimeError("tangent cache configure failed")

statefn=swap.lib.fgc44_approx04_p1b_state_c
statefn.restype=ctypes.c_int
statefn.argtypes=[ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]

block=[0.001,0.01,-0.001,-0.01,0.001,-0.001,0.01,-0.01]
heads=[origin_head.value+x/100.0 for x in block]

def response():
    q,_,t,av=swap.last_trial_response()
    if not av: raise RuntimeError("tangent unavailable")
    return q,t

# Exact reference response from same captured origin for error characterization only.
exact_q=[]
for h in heads:
    q=swap.trial(h); exact_q.append(q); swap.discard()

physical_solves=0
max_abs_error=0.0
max_rel_excursion=0.0
qchecksum=0.0
start=time.perf_counter_ns()

def add_approx(q_anchor,t_anchor,h_anchor,i,h):
    global qchecksum,max_abs_error,max_rel_excursion
    qp=q_anchor+t_anchor*(h-h_anchor)
    qchecksum+=qp
    err=abs(qp-exact_q[i])
    exc=abs(exact_q[i]-q_anchor)
    max_abs_error=max(max_abs_error,err)
    if exc>1e-30: max_rel_excursion=max(max_rel_excursion,err/exc)

if mode=="exact":
    for _ in range(nseq):
        for h in heads:
            q=swap.trial(h); physical_solves+=1; qchecksum+=q; swap.discard()
elif mode in ("e2","e4","eh","ef"):
    for _ in range(nseq):
        q_anchor=None; t_anchor=None; h_anchor=None
        for i,h in enumerate(heads):
            force_exact = (i==0 or i==len(heads)-1)
            if mode=="e2":
                force_exact = force_exact or (i%2==0)
            elif mode=="e4":
                force_exact = force_exact or (i==4)
            elif mode=="eh":
                if h_anchor is not None and abs((h-h_anchor)*100.0)>0.010:
                    force_exact=True
            elif mode=="ef":
                pass
            if force_exact or q_anchor is None:
                q=swap.trial(h); physical_solves+=1; qchecksum+=q
                q_anchor,t_anchor=response(); h_anchor=h
                swap.discard()
            else:
                add_approx(q_anchor,t_anchor,h_anchor,i,h)
else:
    raise RuntimeError("bad mode")

elapsed_ns=time.perf_counter_ns()-start

# Exact final validation and authoritative commit, outside timed discarded-trial loop.
qfinal=swap.trial(heads[-1]); physical_solves+=1
if not swap.swap_preflight(): raise RuntimeError("final SWAP preflight")
swap.prepare_ledger()
if not swap.ledger_preflight(): raise RuntimeError("final ledger preflight")
swap.commit_swap(); swap.commit_ledger()
revision,time_day,count,exchange=swap.state()
ha=(ctypes.c_double*4)(); th=(ctypes.c_double*4)()
if statefn(ha,th): raise RuntimeError("physical state query")

print("SOLVE01_P2B_RAW|"+json.dumps({
 "material":material,"h0":h0,"imbalance":imbalance,"mode":mode,"nseq":nseq,
 "budget_cm":budget,"origin_head_m":origin_head.value,
 "physical_solves":physical_solves,"elapsed_ns":elapsed_ns,
 "ns_per_sequence":elapsed_ns/nseq,"qchecksum":qchecksum,
 "qfinal":qfinal,"revision":revision,"time_day":time_day,
 "ledger_count":count,"ledger_exchange":exchange,
 "heads":list(ha),"theta":list(th),
 "max_abs_error":max_abs_error,"max_rel_excursion":max_rel_excursion
},separators=(",",":")))
PY

COMMON=(-std=f2008 -ffree-line-length-none -O2 -fPIC -fopenmp)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
)
if [[ -n "$PRE_SOURCE" ]]; then MODULE_SRC+=("$PRE_SOURCE"); fi
MODULE_SRC+=(
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  "$TRANSACTION_SOURCE"
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  "$CANONICAL_RUNTIME_SOURCE"
  "$KERNEL_SOURCE"
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
  "$TEMPORAL_INDICATOR_SOURCE"
)
if [[ -n "$EXTRA_SOURCE" ]]; then MODULE_SRC+=("$EXTRA_SOURCE"); fi
MODULE_SRC+=(
  "$HEADCALC_SOURCE"
  "$LEGACY_BINDING_SOURCE"
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

export PYTHONPATH="$ROOT/src/adapter:$ROOT/tests/fgc:$ROOT/tests/fgc/support"
OUT="$BUILD/base01-p0.txt"
: > "$OUT"
cases=("B01|wet|-10" "B01|mid|-75" "B12|wet|-10" "O05|wet|-10" "O14|wet|-10" "O14|mid|-75")
imbalances=(-0.10 0.10)
reps="${BASE01_REPS:-5}"

for case_spec in "${cases[@]}"; do
  IFS='|' read -r material regime h0 <<< "$case_spec"
  for imbalance in "${imbalances[@]}"; do
    for rep in $(seq 1 "$reps"); do
      raw="$(LIBMF6="$BUILD/modflow-bin/libmf6.so" FGC44_SWAP_LIB="$BUILD/lib/libswap.so" \
        python3 "$TEST_SCRIPT" "$material" "$h0" "$imbalance")" || {
          printf '%s\n' "$raw" >&2
          fail "$material $regime $imbalance rep=$rep"
        }
      line="$(printf '%s\n' "$raw" | grep "^${RAW_PREFIX}|" | tail -1)"
      [[ -n "$line" ]] || fail "missing BASE01 P1 record"
      printf '%s|REGIME=%s|REP=%s\n' "$line" "$regime" "$rep" | tee -a "$OUT"
    done
  done
done

if [[ "${BASE01_SKIP_AGGREGATE:-0}" == "1" ]]; then
  exit 0
fi

python3 - "$OUT" <<'PY'
import collections,json,statistics,sys,os
groups=collections.defaultdict(list)
for line in open(sys.argv[1]):
    prefix=os.environ.get("RAW_PREFIX","BASE01_P0_RAW")+"|"
    if not line.startswith(prefix): continue
    payload,tail=line.strip().split("|REGIME=",1)
    regime,rep=tail.split("|REP=",1)
    d=json.loads(payload.split("|",1)[1]); d["regime"]=regime; d["rep"]=int(rep)
    groups[(d["material"],regime,d["imbalance"])].append(d)
if len(groups)!=12: raise SystemExit(f"expected 12 groups, got {len(groups)}")

tot={k:0.0 for k in ("swap_trial_ns","participant_forcing_ns","participant_backend_ns","participant_post_ns")}
calls=0
for key,rs in sorted(groups.items()):
    if len(rs)!=5: raise SystemExit(f"missing reps {key}")
    med={k:statistics.median(float(r[k]) for r in rs) for k in tot}
    for k in tot: tot[k]+=med[k]
    rcalls={int(r["participant_calls"]) for r in rs}
    if len(rcalls)!=1: raise SystemExit(f"nondeterministic participant calls {key}")
    call=next(iter(rcalls)); calls+=call
    total=med["swap_trial_ns"]
    print(
      f"BASE01_P0_GROUP|MATERIAL={key[0]}|REGIME={key[1]}|IMBALANCE={key[2]:.3f}"
      f"|CALLS={call}|SWAP_TRIAL_NS={total:.3f}|FORCING_NS={med['participant_forcing_ns']:.3f}"
      f"|BACKEND_NS={med['participant_backend_ns']:.3f}|POST_NS={med['participant_post_ns']:.3f}"
      f"|FORCING_SHARE={med['participant_forcing_ns']/total:.9f}"
      f"|BACKEND_SHARE={med['participant_backend_ns']/total:.9f}"
      f"|POST_SHARE={med['participant_post_ns']/total:.9f}"
    )
total=tot["swap_trial_ns"]
print(f"BASE01_P0_AGG|CALLS={calls}|SWAP_TRIAL_NS={total:.3f}"
      f"|FORCING_NS={tot['participant_forcing_ns']:.3f}|BACKEND_NS={tot['participant_backend_ns']:.3f}"
      f"|POST_NS={tot['participant_post_ns']:.3f}|FORCING_SHARE={tot['participant_forcing_ns']/total:.9f}"
      f"|BACKEND_SHARE={tot['participant_backend_ns']/total:.9f}|POST_SHARE={tot['participant_post_ns']/total:.9f}")
backend_share=tot["participant_backend_ns"]/total
print(f"BASE01_P0_GATE|BACKEND_SHARE={backend_share:.9f}|REQUIRED_MIN=0.600000000")
if backend_share < 0.60:
    raise SystemExit(f"BASE01 P0 backend share below preregistered 60% gate: {backend_share:.9f}")
print("FPE_BASE01_P0=PASS")
PY
