#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx01-a1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 - "$BUILD/mod_fmr_groundwater_swap_participant.f90" <<'PY'
from pathlib import Path
import sys
src=Path("src/runtime/mod_fmr_groundwater_swap_participant.f90").read_text()

src=src.replace(
"""    logical :: origin_captured = .false.
    logical :: live_candidate = .false.
  contains
""",
"""    logical :: origin_captured = .false.
    logical :: live_candidate = .false.
    logical :: approx_tangent_cache_enabled = .false.
    logical :: cached_tangent_available = .false.
    real(real64) :: cached_tangent = 0.0_real64
    real(real64) :: cached_head_m = 0.0_real64
    real(real64) :: cache_head_limit_m = 0.005_real64
    integer :: cache_max_age = 8
    integer :: cache_age = 0
    integer :: cache_fresh_count = 0
    integer :: cache_reuse_count = 0
    integer(int64) :: cached_lineage_id = 0_int64
    integer(int64) :: cached_revision = -1_int64
    real(real64) :: cached_t0 = 0.0_real64
    real(real64) :: cached_t1 = 0.0_real64
  contains
""",1)

src=src.replace(
"""    procedure, public :: captured_revision => fmr_swap_revision
  end type fmr_groundwater_swap_participant_t
""",
"""    procedure, public :: captured_revision => fmr_swap_revision
    procedure, public :: configure_tangent_cache => fmr_swap_configure_tangent_cache
    procedure, public :: tangent_cache_counts => fmr_swap_tangent_cache_counts
  end type fmr_groundwater_swap_participant_t
""",1)

capture="""    self%origin_captured = .true.
    status = GW_SWAP_PARTICIPANT_OK
"""
capture_rep="""    self%origin_captured = .true.
    self%cached_tangent_available = .false.
    self%cache_age = 0
    status = GW_SWAP_PARTICIPANT_OK
"""
if capture not in src: raise SystemExit("capture seam missing")
src=src.replace(capture,capture_rep,1)

src=src.replace(
"""    real(real64) :: duration_day, qbot_mean_cm_per_day, dq_swap_dh_per_s
    integer :: forcing_status, interface_status
""",
"""    real(real64) :: duration_day, qbot_mean_cm_per_day, dq_swap_dh_per_s
    integer :: forcing_status, interface_status
    logical :: refresh_tangent
""",1)

old="""    trial_numerical = numerical
    trial_numerical%accepted_trajectory_direction%requested = .true.
    trial_numerical%accepted_trajectory_direction%control_coordinate = SW_STEP_CONTROL_BOTTOM_HEAD
"""
new="""    refresh_tangent = .true.
    if (self%approx_tangent_cache_enabled .and. self%cached_tangent_available) then
      refresh_tangent = self%cached_lineage_id /= self%origin_lineage_id .or. &
           self%cached_revision /= self%origin_revision .or. &
           .not. same_time(self%cached_t0, window%t0) .or. .not. same_time(self%cached_t1, window%t1) .or. &
           self%cache_age >= self%cache_max_age .or. &
           abs(prescribed_head_m-self%cached_head_m) > self%cache_head_limit_m .or. &
           .not. ieee_is_finite(self%cached_tangent)
    end if

    trial_numerical = numerical
    trial_numerical%accepted_trajectory_direction%requested = refresh_tangent
    trial_numerical%accepted_trajectory_direction%control_coordinate = SW_STEP_CONTROL_BOTTOM_HEAD
"""
if old not in src: raise SystemExit("numerical seam missing")
src=src.replace(old,new,1)

old="""    if (accepted_head_response_tangent(self%trial_result, window)) then
      dq_swap_dh_per_s = -self%trial_result%accepted_trajectory_direction%accepted_bottom_exchange_derivative / &
           (duration_day * DAY_TO_S)
      if (ieee_is_finite(dq_swap_dh_per_s)) then
        trial%response_tangent_available = .true.
        trial%dq_swap_dh_per_s = dq_swap_dh_per_s
      end if
    end if
"""
new="""    if (refresh_tangent) then
      if (accepted_head_response_tangent(self%trial_result, window)) then
        dq_swap_dh_per_s = -self%trial_result%accepted_trajectory_direction%accepted_bottom_exchange_derivative / &
             (duration_day * DAY_TO_S)
        if (ieee_is_finite(dq_swap_dh_per_s)) then
          trial%response_tangent_available = .true.
          trial%dq_swap_dh_per_s = dq_swap_dh_per_s
          if (self%approx_tangent_cache_enabled) then
            self%cached_tangent_available = .true.
            self%cached_tangent = dq_swap_dh_per_s
            self%cached_head_m = prescribed_head_m
            self%cached_lineage_id = self%origin_lineage_id
            self%cached_revision = self%origin_revision
            self%cached_t0 = window%t0
            self%cached_t1 = window%t1
            self%cache_age = 0
            self%cache_fresh_count = self%cache_fresh_count + 1
          end if
        else
          self%cached_tangent_available = .false.
        end if
      else
        self%cached_tangent_available = .false.
      end if
    else if (self%cached_tangent_available) then
      trial%response_tangent_available = .true.
      trial%dq_swap_dh_per_s = self%cached_tangent
      self%cache_age = self%cache_age + 1
      self%cache_reuse_count = self%cache_reuse_count + 1
    end if
"""
if old not in src: raise SystemExit("tangent publication seam missing")
src=src.replace(old,new,1)

# Invalidate cache at accepted timestep boundaries / abandoned origins.
src=src.replace(
"""    self%origin_captured = .false.
    self%origin_lineage_id = 0_int64
""",
"""    self%origin_captured = .false.
    self%cached_tangent_available = .false.
    self%cache_age = 0
    self%origin_lineage_id = 0_int64
""",1)
src=src.replace(
"""    self%live_candidate = .false.
    self%origin_captured = .false.
    status = GW_SWAP_PARTICIPANT_OK
""",
"""    self%live_candidate = .false.
    self%origin_captured = .false.
    self%cached_tangent_available = .false.
    self%cache_age = 0
    status = GW_SWAP_PARTICIPANT_OK
""",1)

insert="""
  subroutine fmr_swap_configure_tangent_cache(self, enabled, head_limit_m, max_age)
    class(fmr_groundwater_swap_participant_t), intent(inout) :: self
    logical, intent(in) :: enabled
    real(real64), intent(in), optional :: head_limit_m
    integer, intent(in), optional :: max_age
    self%approx_tangent_cache_enabled = enabled
    if (present(head_limit_m)) self%cache_head_limit_m = max(0.0_real64, head_limit_m)
    if (present(max_age)) self%cache_max_age = max(1, max_age)
    self%cached_tangent_available = .false.
    self%cache_age = 0
    self%cache_fresh_count = 0
    self%cache_reuse_count = 0
  end subroutine fmr_swap_configure_tangent_cache

  subroutine fmr_swap_tangent_cache_counts(self, fresh_count, reuse_count)
    class(fmr_groundwater_swap_participant_t), intent(in) :: self
    integer, intent(out) :: fresh_count, reuse_count
    fresh_count = self%cache_fresh_count
    reuse_count = self%cache_reuse_count
  end subroutine fmr_swap_tangent_cache_counts

"""
idx=src.rfind("end module mod_fmr_groundwater_swap_participant")
if idx<0: raise SystemExit("module end missing")
src=src[:idx]+insert+src[idx:]
Path(sys.argv[1]).write_text(src)
PY

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fgc/test_fgc44_real_fmr_participant.f90").read_text()
start=src.index("  call participant%capture_origin(committed,status)")
end=src.index("\ncontains\n",start)

replacement=r"""  call participant%configure_tangent_cache(.true.,0.005_real64,8)
  call participant%capture_origin(committed,status)
  call require(status==GW_SWAP_PARTICIPANT_OK,'capture FMR accepted origin')

  call system_clock(c0,rate)
  qsum=0.0_real64; tsum=0.0_real64
  do iter=1,ntrial
    call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,datum,window, &
         origin_head_m,trial1,status)
    call require(status==GW_SWAP_PARTICIPANT_OK .and. trial1%valid,'A1 repeated trial')
    call require(trial1%response_tangent_available,'A1 tangent available')
    qsum=qsum+trial1%q_swap_m_per_s
    tsum=tsum+trial1%dq_swap_dh_per_s
    call participant%discard_candidate(backend)
  end do
  call system_clock(c1)
  cached_seconds=real(c1-c0,real64)/real(rate,real64)
  call participant%tangent_cache_counts(fresh_count,reuse_count)
  call require(fresh_count>0 .and. reuse_count>0,'A1 cache exercised')
  call require(fresh_count+reuse_count==ntrial,'A1 cache accounting')

  call participant%configure_tangent_cache(.false.)
  call participant%abandon_origin(status)
  call require(status==GW_SWAP_PARTICIPANT_OK,'A1 abandon cached origin')
  call participant%capture_origin(committed,status)
  call require(status==GW_SWAP_PARTICIPANT_OK,'capture fresh benchmark origin')

  call system_clock(c0,rate)
  qsum_fresh=0.0_real64; tsum_fresh=0.0_real64
  do iter=1,ntrial
    call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,datum,window, &
         origin_head_m,trial2,status)
    call require(status==GW_SWAP_PARTICIPANT_OK .and. trial2%valid,'fresh repeated trial')
    call require(trial2%response_tangent_available,'fresh tangent available')
    qsum_fresh=qsum_fresh+trial2%q_swap_m_per_s
    tsum_fresh=tsum_fresh+trial2%dq_swap_dh_per_s
    call participant%discard_candidate(backend)
  end do
  call system_clock(c1)
  fresh_seconds=real(c1-c0,real64)/real(rate,real64)

  call require(qsum==qsum_fresh,'A1 physical exchange identity')
  call require(tsum==tsum_fresh,'A1 same-head tangent identity')
  write(*,'(*(g0))') 'APPROX01_A1|TRIALS=',ntrial,'|FRESH_COUNT=',fresh_count,'|REUSE_COUNT=',reuse_count, &
       '|CACHED_NS_PER_TRIAL=',1.0e9_real64*cached_seconds/real(ntrial,real64), &
       '|FRESH_NS_PER_TRIAL=',1.0e9_real64*fresh_seconds/real(ntrial,real64), &
       '|RATIO=',cached_seconds/fresh_seconds,'|SPEEDUP_PERCENT=',100.0_real64*(1.0_real64-cached_seconds/fresh_seconds), &
       '|QSUM=',qsum,'|TSUM=',tsum
  write(*,'(A)') 'FPE_APPROX01_A1_PARTICIPANT=PASS'
"""
src=src[:start]+replacement+src[end:]
src=src.replace(
"  real(real64) :: qeq, committed_time, origin_head_m\n",
"  real(real64) :: qeq, committed_time, origin_head_m\n"
"  real(real64) :: cached_seconds,fresh_seconds,qsum,qsum_fresh,tsum,tsum_fresh\n"
"  integer(int64) :: c0,c1,rate\n"
"  integer :: iter,fresh_count,reuse_count\n"
"  integer, parameter :: ntrial=20000\n"
)
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
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  "$BUILD/mod_fmr_groundwater_swap_participant.f90"
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$BUILD/test.f90" -o "$BUILD/test.o"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

"$BUILD/test"
