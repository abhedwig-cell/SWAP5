#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TMP_FIX="tests/fgc/support/.fahl49_direct_context_fixture_$.f90"
TMP_RUN="tests/fgc/.run_fahl49_direct_context_$.sh"
TMP_PY="tests/fgc/.test_fahl49_direct_context_$.py"
trap 'rm -f "$TMP_FIX" "$TMP_RUN" "$TMP_PY"' EXIT

python3 - "$TMP_FIX" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fgc/support/mod_fgc49d_application_context_fixture.f90").read_text()
src=src.replace(
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &\n       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state",
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &\n       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state, &\n       prepare_fmr_b110_default_mvg")
src=src.replace(
"  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t",
"  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t\n"
"  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t")
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
    if (direct_payload /= 6240_int64 .or. .not. direct_frozen) return
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
"  public :: fgc49d_fixture_state_c\n  public :: fgc49d_fixture_probe_trial_c")
probe = r'''
  integer(c_int) function fgc49d_fixture_probe_trial_c(registry_status, participant_status, trial_valid, tangent_available) &
       bind(C, name="fgc49d_fixture_probe_trial_c") result(c_status)
    integer(c_int), intent(out) :: registry_status, participant_status, trial_valid, tangent_available
    type(groundwater_coupling_window_t) :: window
    type(groundwater_swap_trial_t) :: trial
    integer :: local_status, part_status, cleanup_status

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
    c_status = 0_c_int
  end function fgc49d_fixture_probe_trial_c
'''
marker="  subroutine make_predictor(input, tile_id, swap_lineage, coupling_id, service_id, gw_lineage, h0, h1)"
if marker not in src:
    raise SystemExit("probe insertion seam missing")
src=src.replace(marker,probe+"\n"+marker,1)
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

bash "$TMP_RUN" | tee /tmp/fahl49-application-context-$.txt
grep -Fq 'FGC49D_THREE_REAL_SWAP_AND_LEDGER_COMMITS=PASS' /tmp/fahl49-application-context-$$.txt
grep -Fq 'F-GC49D PRODUCTION APPLICATION CONTEXT ABI GATE PASS' /tmp/fahl49-application-context-$$.txt
rm -f /tmp/fahl49-application-context-$$.txt

echo 'FAHL49_APPLICATION_OPTIN=PASS'
echo 'FAHL49_APPLICATION_GATE=PASS'
