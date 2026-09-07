#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = (root / 'src/adapter/mod_b1_10_process_checkpoint.f90').read_text()
kernel = (root / 'src/kernel/mod_kernel_transactions.f90').read_text().lower()
contract = json.loads((root / 'integration/f-kt/F-KT07_MACROPORE_CONTINUATION_CONTRACT.json').read_text())

required = [
    'type, public :: b1_10_macropore_continuation_t',
    'integer :: nstep = 0',
    'type(b1_10_macropore_continuation_t), allocatable :: macropore',
    'bind_b1_10_macropore_continuation',
    'read_b1_10_macropore_continuation',
    'clear_b1_10_macropore_continuation',
    'b1_10_macropore_continuation_complete',
    'target%macropore = self%macropore',
]
for token in required:
    if token not in source:
        raise SystemExit(f'FKT07_CONTRACT_GATE missing source token: {token}')

for forbidden in ['mod_a23bu_worker_execution_context', 'headcalc', 'flwarn', 'iwarn']:
    if forbidden.lower() in source.lower():
        raise SystemExit(f'FKT07_CONTRACT_GATE forbidden adapter dependency: {forbidden}')

for forbidden in ['nstep', 'a23bu_solver_history', 'mod_a23bu_worker_execution_context']:
    if forbidden in kernel:
        raise SystemExit(f'FKT07_CONTRACT_GATE generic kernel leaked adapter/F-SI state: {forbidden}')

if contract['ownership']['generic_kernel_knows_nstep'] is not False:
    raise SystemExit('FKT07_CONTRACT_GATE contract generic-kernel ownership changed')
if contract['admission_boundaries']['macropore_production_admitted_by_fkt07'] is not False:
    raise SystemExit('FKT07_CONTRACT_GATE macropore production admission must remain false')
if contract['admission_boundaries']['reference_execution_admitted_by_fkt07'] is not False:
    raise SystemExit('FKT07_CONTRACT_GATE reference execution must remain fail-closed')
if contract['materialization']['implicit_capture_from_legacy_history'] is not False:
    raise SystemExit('FKT07_CONTRACT_GATE implicit history capture is forbidden')

print('FKT07_CONTRACT_GATE PASS')
