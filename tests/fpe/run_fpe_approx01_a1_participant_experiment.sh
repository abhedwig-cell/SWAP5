#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx01-a1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

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

  cached_fresh_count=fresh_count
  cached_reuse_count=reuse_count
  fresh_before=fresh_count
  reuse_before=reuse_count
  call participant%abandon_origin(status)
  call require(status==GW_SWAP_PARTICIPANT_OK,'A1 abandon cached origin for invalidation')
  call participant%capture_origin(committed,status)
  call require(status==GW_SWAP_PARTICIPANT_OK,'A1 recapture origin')
  call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,datum,window, &
       origin_head_m,trial2,status)
  call require(status==GW_SWAP_PARTICIPANT_OK .and. trial2%valid,'A1 recaptured trial')
  call require(trial2%response_tangent_available,'A1 recaptured tangent available')
  call participant%tangent_cache_counts(fresh_count,reuse_count)
  call require(fresh_count==fresh_before+1,'A1 new origin forces fresh tangent')
  call require(reuse_count==reuse_before,'A1 new origin does not reuse stale tangent')
  call participant%discard_candidate(backend)

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
  write(*,'(*(g0))') 'APPROX01_A1|TRIALS=',ntrial,'|FRESH_COUNT=',cached_fresh_count,'|REUSE_COUNT=',cached_reuse_count, &
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
  src/runtime/mod_fmr_groundwater_swap_participant.f90
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
