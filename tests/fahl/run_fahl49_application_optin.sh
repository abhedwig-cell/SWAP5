#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TMP_FIX="tests/fgc/support/.fahl49_direct_context_fixture_$$.f90"
TMP_RUN="tests/fgc/.run_fahl49_direct_context_$$.sh"
trap 'rm -f "$TMP_FIX" "$TMP_RUN"' EXIT

python3 - "$TMP_FIX" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fgc/support/mod_fgc49d_application_context_fixture.f90").read_text()
src=src.replace(
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &\n       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state",
"  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &\n       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state, &\n       prepare_fmr_b110_default_mvg")
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
Path(sys.argv[1]).write_text(src)
PY

python3 - "$TMP_RUN" "$TMP_FIX" <<'PY'
from pathlib import Path
import sys
runner=Path("tests/fgc/run_fgc49d_production_application_context.sh").read_text()
runner=runner.replace("tests/fgc/support/mod_fgc49d_application_context_fixture.f90",sys.argv[2])
needle="  src/solver/mod_b110_default_mvg_provider.f90\n"
insert=needle+"  src/solver/mod_b110_direct_retention_core.f90\n  src/solver/mod_b110_direct_retention_provider.f90\n"
if "src/solver/mod_b110_direct_retention_core.f90" not in runner:
    if needle not in runner:
        raise SystemExit("FGC49D compile seam missing")
    runner=runner.replace(needle,insert,1)
Path(sys.argv[1]).write_text(runner)
PY

chmod +x "$TMP_RUN"
bash "$TMP_RUN" | tee /tmp/fahl49-application-context-$$.txt
grep -Fq 'FGC49D_THREE_REAL_SWAP_AND_LEDGER_COMMITS=PASS' /tmp/fahl49-application-context-$$.txt
grep -Fq 'F-GC49D PRODUCTION APPLICATION CONTEXT ABI GATE PASS' /tmp/fahl49-application-context-$$.txt
rm -f /tmp/fahl49-application-context-$$.txt

echo 'FAHL49_APPLICATION_OPTIN=PASS'
echo 'FAHL49_APPLICATION_GATE=PASS'
