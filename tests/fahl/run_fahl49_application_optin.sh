#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TMP_FIX="tests/fgc/support/.fahl49_direct_context_fixture_$.f90"
TMP_RUN="tests/fgc/.run_fahl49_direct_context_$.sh"
TMP_PY="tests/fgc/.test_fahl49_direct_context_$.py"
TMP_OUT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/fahl49-application-context-$.txt"
trap 'rm -f "$TMP_FIX" "$TMP_RUN" "$TMP_PY" "$TMP_OUT"' EXIT

python3 - "$TMP_FIX" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fgc/support/mod_fgc49d_application_context_fixture.f90").read_text()
src=src.replace(
"  use mod_canonical_contracts, only: canonical_numerical_config_t",
"  use mod_canonical_contracts, only: canonical_forcing_t, canonical_numerical_config_t")
src=src.replace(
"  use mod_kernel_transactions, only: kernel_committed_state_t",
"  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &\n"
"       kernel_candidate_state_t, kernel_diagnostics_t")
src=src.replace(
"  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE",
"  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE\n"
"  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_HEAD")
src=src.replace(
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &\n       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state",
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &\n       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state, &\n       prepare_fmr_b110_default_mvg")
src=src.replace(
"  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_HEAD",
"  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_HEAD")
src=src.replace(
"  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_HEAD",
"  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_HEAD")
src=src.replace(
"  use mod_canonical_contracts, only: canonical_numerical_config_t",
"  use mod_canonical_contracts, only: canonical_forcing_t, canonical_numerical_config_t")
src=src.replace(
"  use mod_kernel_transactions, only: kernel_committed_state_t",
"  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &\n"
"       kernel_candidate_state_t, kernel_diagnostics_t")
src=src.replace(
"  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t",
"  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t\n"
"  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t")
src=src.replace(
"  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &\n       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY",
"  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &\n       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY\n"
"  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_HEAD")
src=src.replace(
"  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t",
"  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t\n"
"  use mod_b110_direct_retention_core, only: reset_b110_direct_retention_pool, freeze_b110_direct_retention_pool, &\n"
"       b110_direct_retention_pool_stats")
src=src.replace(
"    integer :: i, status",
"    integer :: i, status, direct_entries, direct_builds, direct_hits\n"
"    integer(int64) :: direct_payload\n"
"    logical :: direct_frozen")
needle="""    call initialize_parameters(parameters)
    call initialize_forcing(base_forcing, PREDICTOR_QBOT)"""
insert="""    call initialize_parameters(parameters)
    parameters%direct_retention_active = .true.
    call reset_b110_direct_retention_pool()
    call prepare_fmr_b110_default_mvg(parameters, ok)
    if (.not. ok .or. parameters%prepared_direct_retention_slot <= 0) return
    call freeze_b110_direct_retention_pool()
    call b110_direct_retention_pool_stats(direct_entries,direct_builds,direct_hits,direct_payload,direct_frozen)
    if (direct_entries /= 1 .or. direct_builds /= 1 .or. direct_hits /= 0) return
    if (direct_payload /= 12384_int64 .or. .not. direct_frozen) return
    call initialize_forcing(base_forcing, PREDICTOR_QBOT)"""
if needle not in src:
    raise SystemExit("fixture direct-retention insertion seam missing")
src=src.replace(needle,insert,1)
bind_old="""      call registry%bind(TILE_ID(i), backend, columns(i), templates(i), parameters, committed(i), materializer, &
           config, datum, handles(i), status)"""
bind_new="""      call registry%bind(TILE_ID(i), backend, columns(i), templates(i), parameters, committed(i), materializer, &
           config, datum, handles(i), status, immutable_parameters=.true.)"""
if bind_old not in src:
    raise SystemExit("registry bind seam missing")
src=src.replace(bind_old,bind_new)
src=src.replace(
"  public :: fgc49d_fixture_state_c",
"  public :: fgc49d_fixture_state_c\n  public :: fgc49d_fixture_probe_trial_c\n  public :: fgc49d_fixture_probe_backend_c")
probe = r'''
  integer(c_int) function fgc49d_fixture_probe_trial_c(registry_status, participant_status, trial_valid, tangent_available) &
       bind(C, name="fgc49d_fixture_probe_trial_c") result(c_status)
    integer(c_int), intent(out) :: registry_status, participant_status, trial_valid, tangent_available
    type(groundwater_coupling_window_t) :: window
    type(groundwater_swap_trial_t) :: trial
    type(groundwater_head_datum_t) :: probe_datum
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: direct_result
    type(kernel_candidate_state_t) :: direct_candidate
    type(kernel_diagnostics_t) :: direct_diagnostics
    type(canonical_numerical_config_t) :: direct_numerical
    class(canonical_forcing_t), allocatable :: probe_forcing
    integer :: local_status, part_status, cleanup_status, forcing_status
    logical :: checkpoint_ok

    c_status = 1_c_int
    registry_status = -1_c_int
    participant_status = -1_c_int
    trial_valid = 0_c_int
    tangent_available = 0_c_int
    if (.not. initialized) return

    call registry%capture_origin(handles(1), part_status, local_status)
    registry_status = int(local_status,c_int)
    participant_status = int(part_status,c_int)
    if (local_status /= FMR_GW_REGISTRY_OK) then
      c_status = 0_c_int
      return
    end if

    window%t0 = 0.0_real64
    window%t1 = DURATION_DAY
    call registry%trial_from_origin(handles(1),window,reference_head_m,trial,part_status,local_status)
    registry_status = int(local_status,c_int)
    participant_status = int(part_status,c_int)
    if (trial%valid) trial_valid = 1_c_int
    if (trial%response_tangent_available) tangent_available = 1_c_int
    if (trial%valid) call registry%discard_candidate(handles(1),cleanup_status)
    call registry%abandon_origin(handles(1),cleanup_status)

    call committed(1)%capture_checkpoint(checkpoint,checkpoint_ok)
    probe_datum%available=.true.
    probe_datum%datum_id=610049_int64
    probe_datum%bottom_boundary_elevation_m=0.0_real64
    call materializer%materialize(reference_head_m,probe_datum,probe_forcing,forcing_status)
    direct_numerical=config
    direct_numerical%accepted_trajectory_direction%requested=.true.
    direct_numerical%accepted_trajectory_direction%control_coordinate=SW_STEP_CONTROL_BOTTOM_HEAD
    if (checkpoint_ok .and. allocated(probe_forcing)) then
      select type(typed_forcing=>probe_forcing)
      type is(fmr_b110_physical_forcing_t)
        call backend%run_trial(columns(1),templates(1),parameters,committed(1),typed_forcing,direct_numerical, &
             0.0_real64,DURATION_DAY,checkpoint,direct_result,direct_candidate,direct_diagnostics, &
             trusted_prepared_parameters=.true.)
        write(*,'(*(g0))') 'FAHL49_DIRECT_KERNEL_STATUS=',direct_result%status
        write(*,'(*(g0))') 'FAHL49_DIRECT_COMPLETED=',direct_result%completed
        write(*,'(*(g0))') 'FAHL49_DIRECT_CANDIDATE_READY=',direct_candidate%ready()
        write(*,'(*(g0))') 'FAHL49_DIRECT_BOTTOM_AVAILABLE=',direct_result%bottom_interface_exchange_available
        write(*,'(*(g0))') 'FAHL49_DIRECT_COMPLETED_T=',direct_result%completed_t
        write(*,'(*(g0))') 'FAHL49_DIRECT_DIRECTION_REQUESTED=',direct_result%accepted_trajectory_direction%requested
        write(*,'(*(g0))') 'FAHL49_DIRECT_DIRECTION_AVAILABLE=',direct_result%accepted_trajectory_direction%available
        write(*,'(*(g0))') 'FAHL49_DIRECT_ACCEPTED_STEPS=',direct_result%accepted_trajectory_direction%accepted_steps
      class default
        write(*,'(A)') 'FAHL49_DIRECT_FORCING_TYPE=UNEXPECTED'
      end select
    else
      write(*,'(*(g0))') 'FAHL49_DIRECT_CHECKPOINT_OK=',checkpoint_ok
      write(*,'(*(g0))') 'FAHL49_DIRECT_FORCING_STATUS=',forcing_status
    end if
    c_status = 0_c_int
  end function fgc49d_fixture_probe_trial_c
'''

backend_probe = r'''
  integer(c_int) function fgc49d_fixture_probe_backend_c() bind(C, name="fgc49d_fixture_probe_backend_c") result(c_status)
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    class(canonical_forcing_t), allocatable :: forcing
    type(canonical_numerical_config_t) :: trial_numerical
    type(groundwater_head_datum_t) :: local_datum
    logical :: available
    integer :: forcing_status, cleanup_status

    c_status = 1_c_int
    if (.not. initialized) return
    call committed(1)%capture_checkpoint(checkpoint, available)
    write(*,'(A,I0)') 'FAHL49_BACKEND_CHECKPOINT_READY=', merge(1,0,available .and. checkpoint%ready())
    if (.not. available .or. .not. checkpoint%ready()) then
      c_status = 0_c_int
      return
    end if

    local_datum%available = .true.
    local_datum%datum_id = 610049_int64
    local_datum%bottom_boundary_elevation_m = 0.0_real64
    call materializer%materialize(reference_head_m, local_datum, forcing, forcing_status)
    write(*,'(A,I0)') 'FAHL49_BACKEND_FORCING_STATUS=', forcing_status
    if (forcing_status /= 0 .or. .not. allocated(forcing)) then
      c_status = 0_c_int
      return
    end if

    trial_numerical = config
    trial_numerical%accepted_trajectory_direction%requested = .true.
    trial_numerical%accepted_trajectory_direction%control_coordinate = SW_STEP_CONTROL_BOTTOM_HEAD

    select type (typed_forcing => forcing)
    type is (fmr_b110_physical_forcing_t)
      call backend%run_trial(columns(1), templates(1), parameters, committed(1), typed_forcing, trial_numerical, &
           0.0_real64, DURATION_DAY, checkpoint, result, candidate, diagnostics, trusted_prepared_parameters=.true.)
      write(*,'(A,I0)') 'FAHL49_BACKEND_RESULT_STATUS=', result%status
      write(*,'(A,I0)') 'FAHL49_BACKEND_COMPLETED=', merge(1,0,result%completed)
      write(*,'(A,I0)') 'FAHL49_BACKEND_CANDIDATE_READY=', merge(1,0,candidate%ready())
      write(*,'(A,I0)') 'FAHL49_BACKEND_BOTTOM_AVAILABLE=', merge(1,0,result%bottom_interface_exchange_available)
      write(*,'(A,ES24.16E3)') 'FAHL49_BACKEND_REQUESTED_T0=', result%requested_t0
      write(*,'(A,ES24.16E3)') 'FAHL49_BACKEND_REQUESTED_T1=', result%requested_t1
      write(*,'(A,ES24.16E3)') 'FAHL49_BACKEND_COMPLETED_T=', result%completed_t
      write(*,'(A,I0)') 'FAHL49_BACKEND_TX_CALLS=', diagnostics%transaction_calls
      write(*,'(A,I0)') 'FAHL49_BACKEND_ACCEPTED_SUBSTEPS=', diagnostics%accepted_substeps
      write(*,'(A,I0)') 'FAHL49_BACKEND_ATTEMPTS=', diagnostics%attempts
      write(*,'(A,I0)') 'FAHL49_BACKEND_RETRIES=', diagnostics%retries
      write(*,'(A,I0)') 'FAHL49_BACKEND_SOLVER_REJECTIONS=', diagnostics%solver_rejections
      write(*,'(A,I0)') 'FAHL49_BACKEND_TEMPORAL_REJECTIONS=', diagnostics%temporal_rejections
      write(*,'(A,I0)') 'FAHL49_BACKEND_TEMPORAL_CERT_REJECTIONS=', diagnostics%temporal_certificate_unavailable_rejections
      write(*,'(A,I0)') 'FAHL49_BACKEND_MASS_REJECTIONS=', diagnostics%mass_rejections
      write(*,'(A,I0)') 'FAHL49_BACKEND_ADMISSION_REJECTIONS=', diagnostics%admission_rejections
      write(*,'(A,I0)') 'FAHL49_BACKEND_NONLINEAR_ITER=', diagnostics%nonlinear_iterations
      write(*,'(A,I0)') 'FAHL49_BACKEND_INTERNAL_RETRIES=', diagnostics%internal_retries
      if (candidate%ready()) call backend%discard_trial_candidate(candidate, diagnostics)
    class default
      write(*,'(A)') 'FAHL49_BACKEND_FORCING_TYPE=INVALID'
    end select
    c_status = 0_c_int
  end function fgc49d_fixture_probe_backend_c
'''

marker="  subroutine make_predictor(input, tile_id, swap_lineage, coupling_id, service_id, gw_lineage, h0, h1)"
if marker not in src:
    raise SystemExit("probe insertion seam missing")
src=src.replace(marker,probe+"\n"+backend_probe+"\n"+marker,1)
Path(sys.argv[1]).write_text(src)
PY

python3 - "$TMP_PY" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_text(r'''from __future__ import annotations
import ctypes, os, subprocess, sys
from pathlib import Path

libpath=Path(os.environ["FGC49D_APPLICATION_LIB"]).resolve()
lib=ctypes.CDLL(str(libpath))
init=lib.fgc49d_fixture_initialize_c
init.restype=ctypes.c_int
init.argtypes=[ctypes.POINTER(ctypes.c_int64),ctypes.POINTER(ctypes.c_double),ctypes.POINTER(ctypes.c_double)]
handle=ctypes.c_int64(); h1=ctypes.c_double(); h2=ctypes.c_double()
init_status=int(init(ctypes.byref(handle),ctypes.byref(h1),ctypes.byref(h2)))
probe=lib.fgc49d_fixture_probe_trial_c
probe.restype=ctypes.c_int
probe.argtypes=[ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int)]
rs=ctypes.c_int(); ps=ctypes.c_int(); tv=ctypes.c_int(); ta=ctypes.c_int()
probe_status=int(probe(ctypes.byref(rs),ctypes.byref(ps),ctypes.byref(tv),ctypes.byref(ta)))
backend_probe=lib.fgc49d_fixture_probe_backend_c
backend_probe.restype=ctypes.c_int
backend_probe.argtypes=[]
backend_probe_status=int(backend_probe())
print(f"FAHL49_BACKEND_PROBE_STATUS={backend_probe_status}",flush=True)
print(f"FAHL49_PROBE_INIT_STATUS={init_status}",flush=True)
print(f"FAHL49_PROBE_STATUS={probe_status}",flush=True)
print(f"FAHL49_PROBE_REGISTRY_STATUS={rs.value}",flush=True)
print(f"FAHL49_PROBE_PARTICIPANT_STATUS={ps.value}",flush=True)
print(f"FAHL49_PROBE_TRIAL_VALID={tv.value}",flush=True)
print(f"FAHL49_PROBE_TANGENT_AVAILABLE={ta.value}",flush=True)
env=os.environ.copy()
raise SystemExit(subprocess.call([sys.executable,"tests/fgc/test_fgc49d_production_application_context.py"],env=env))
''')
PY

python3 - "$TMP_RUN" "$TMP_FIX" "$TMP_PY" <<'PY'
from pathlib import Path
import sys
runner=Path("tests/fgc/run_fgc49d_production_application_context.sh").read_text()
runner=runner.replace("tests/fgc/support/mod_fgc49d_application_context_fixture.f90",sys.argv[2])
runner=runner.replace("tests/fgc/test_fgc49d_production_application_context.py",sys.argv[3])
provider_needle="  src/solver/mod_b110_default_mvg_provider.f90\n"
directional_needle="  src/solver/mod_b110_default_mvg_directional_provider.f90\n"
if "src/solver/mod_b110_direct_retention_core.f90" not in runner:
    if provider_needle not in runner or directional_needle not in runner:
        raise SystemExit("FGC49D compile seam missing")
    runner=runner.replace(provider_needle,provider_needle+"  src/solver/mod_b110_direct_retention_core.f90\n",1)
    runner=runner.replace(directional_needle,directional_needle+"  src/solver/mod_b110_direct_retention_provider.f90\n",1)
Path(sys.argv[1]).write_text(runner)
PY

chmod +x "$TMP_RUN"

bash "$TMP_RUN" | tee "$TMP_OUT"
grep -Fq 'FGC49D_THREE_REAL_SWAP_AND_LEDGER_COMMITS=PASS' "$TMP_OUT"
grep -Fq 'F-GC49D PRODUCTION APPLICATION CONTEXT ABI GATE PASS' "$TMP_OUT"

echo 'FAHL49_APPLICATION_OPTIN=PASS'
echo 'FAHL49_APPLICATION_GATE=PASS'
