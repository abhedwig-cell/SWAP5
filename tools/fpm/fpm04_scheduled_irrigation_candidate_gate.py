#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

root = Path('.')
base = 'ad42be53e75ecc6375fcbb832492b203303f7855'
process_path = root / 'src/process/mod_irrigation_process.f90'
process = process_path.read_text(encoding='utf-8').lower()
contract = json.loads((root / 'integration/f-pm/F-PM04_CANDIDATE_CONTRACT.json').read_text(encoding='utf-8'))
selection = json.loads((root / 'integration/f-pm/F-PM04_SELECTION_OPPORTUNITY_EVIDENCE.json').read_text(encoding='utf-8'))
source = json.loads((root / 'integration/f-pm/F-PM04_B110_SOURCE_EVIDENCE.json').read_text(encoding='utf-8'))

changed_src = subprocess.check_output(['git','diff','--name-only',base,'HEAD','--','src'], text=True).splitlines()
assert changed_src == ['src/process/mod_irrigation_process.f90'], f'unexpected production scope: {changed_src}'
print('FPM04_CANDIDATE_PRODUCTION_SCOPE PASS')

expected_blobs = {
    'src/solver/mod_process_hydraulic_view.f90': 'd7d85fe71ced0d94b29c8d9395859ae1834f7dd6',
    'src/runtime/mod_fmr_process_hydraulic_view_binding.f90': '37f5968ffe00b1ff56f824f77ab94d3825171acf',
    'src/runtime/mod_fmr_serialized_reference_backend.f90': '202ab846cbd30d149d0d450249b3d517e333994f',
    'src/runtime/mod_fmr_serialized_multiswap_runtime.f90': '1bb0c6d4683db2729d48de31babcea72bc1a6caf',
    'src/kernel/mod_kernel_transactions.f90': '9f7c16e71cfb93b57f796ba759bae73824318a2f',
    'src/solver/mod_b110_source_sink_provider.f90': 'd6c57add72387e5c0022a44319fff08046194aac',
}
for path, expected in expected_blobs.items():
    actual = subprocess.check_output(['git','hash-object',path], text=True).strip()
    assert actual == expected, f'owner blob changed: {path}: {actual}'
print('FPM04_CANDIDATE_OWNER_BLOBS PASS')

assert contract['exact_candidate_base'] == base
assert contract['selection_semantics']['new_start_requires_selection_opportunity'] is True
assert contract['selection_semantics']['infer_midnight'] is False
assert contract['selection_semantics']['infer_one_day_interval'] is False
assert contract['selection_semantics']['active_scheduled_event_continues_without_selection_opportunity'] is True
assert selection['target_semantic_consequence']['explicit_input'] == 'selection_opportunity'
assert selection['architectural_effect']['kernel_day_counter_added'] is False
assert source['b110_identity']['irrigation_sha256'] == '65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1'
assert source['b110_identity']['functions_sha256'] == 'b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527'
print('FPM04_CANDIDATE_SOURCE_CONTRACT PASS')

required = [
    'type, public :: scheduled_irrigation_parameters_t',
    'type, public :: scheduled_irrigation_request_t',
    'logical :: selection_opportunity = .false.',
    'integer :: active_event_origin = irrigation_event_none',
    'public :: evaluate_scheduled_irrigation_interval',
    'type(process_hydraulic_view_t), intent(in) :: hydraulic_view',
    'if (.not. request%selection_opportunity) return',
    'if (request%fixed_event_already_selected) return',
    'if (hydraulic_view%pressure_head(parameters%sensor_node) > threshold) return',
    'candidate_state%active_event_origin = irrigation_event_scheduled',
    'candidate_state%active_event_index = 0',
    'fluxes%subsurface_source(parameters%single_ssdi_node) = parameters%irr_rate_cm_per_day',
    'fluxes%external_inflow_amount = parameters%irr_rate_cm_per_day * active_duration',
    'if (knot_count < irrigation_max_scheduled_knots) return',
    'diagnostics%status = irrigation_split_required',
]
for token in required:
    assert token in process, f'missing candidate token: {token}'

forbidden = [
    'fldaystart', 'fldayend', 't1900', 'dayfix', 'tcsfix',
    'headcalc', 'reference_richards', 'open(', 'close(', 'inquire(', 'read(', 'write(',
    'rdinit', 'rdfdor', 'rdatim', 'common /', 'save ::', 'omp_lib'
]
for token in forbidden:
    assert token not in process, f'forbidden dependency/time assumption: {token}'

assert 'active_event_origin = irrigation_event_fixed' in process
assert 'state%active_event_origin = irrigation_event_none' in process
print('FPM04_CANDIDATE_EVENT_ORIGIN_STATE PASS')
print('FPM04_CANDIDATE_GENERIC_SELECTION_TIME PASS')
print('FPM04_CANDIDATE_SINGLE_NODE_SSDI PASS')
