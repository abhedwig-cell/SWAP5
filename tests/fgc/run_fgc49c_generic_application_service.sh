#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
from pathlib import Path
src=Path('src/adapter/modflow6_groundwater_application_service.py').read_text()
low=src.lower()
for token in [
    'run_groundwater_application_window',
    'modflow6preparedsolvesession',
    'trial_cell_heads',
    'evaluate_groundwater_fluxes',
    'relinearize_terms',
    'timestep_ready_for_finalize',
    'finalize_time_step_once',
    'commit_swaps',
    'commit_ledgers',
]:
    assert token in low, token
for forbidden in [
    '7001','7002','fgc47','fgc46','fgc45','fgc44',
    '86400.0','area_fraction','q_u_at_reference_m_per_s','dq_u_dh_per_s',
    'reference_volume_flux_m3_per_day',
    'compose_modflow6_multiswap_cell_response',
    'compose_modflow6_linear_boundary_term',
    'imod coupler',
]:
    assert forbidden not in low, forbidden
print('FGC49C_GENERIC_SERVICE_NO_TOPOLOGY_HARDCODING=PASS')
print('FGC49C_NO_CELL_MATH_DUPLICATION=PASS')
print('FGC49C_NO_IMOD_COUPLER_OWNERSHIP=PASS')
PY

python3 tests/fgc/test_fgc49c_generic_application_service.py
echo 'F-GC49C DETERMINISTIC GENERIC APPLICATION SERVICE GATE PASS'
