#!/usr/bin/env python3
import json
from pathlib import Path

root = Path('.')
process = (root / 'src/process/mod_irrigation_process.f90').read_text(encoding='utf-8').lower()
contract = json.loads((root / 'integration/f-pm/F-PM03_FIXED_EVENT_SEAM_CONTRACT.json').read_text(encoding='utf-8'))
oracle = json.loads((root / 'integration/f-pm/F-PM03_B110_FIXED_EVENT_ORACLE.json').read_text(encoding='utf-8'))

expected_oracle_sha = '65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1'
assert contract['source_basis']['fmr07_qualified_head'] == 'afb450bed0d53d20af2157d0b164d16a9e0a04cd'
assert contract['source_basis']['fsi17_qualified_head'] == 'fca2f497e465c4782ebc6e25756aff70cbb2554e'
assert contract['source_basis']['b110_irrigation_oracle_sha256'] == expected_oracle_sha
assert oracle['source']['sha256'] == expected_oracle_sha
assert oracle['source']['verified_from_project_archive'] is True
assert contract['readiness_transition']['production_migration_allowed'] is True
assert contract['scientific_admission'].startswith('Independent F-VQ')

required = [
    'type(irrigation_parameters_t), intent(in) :: parameters',
    'type(irrigation_state_t), intent(in) :: committed_state',
    'type(irrigation_state_t), intent(out) :: candidate_state',
    'candidate_state = committed_state',
    'irrigation_fixed_event_match_tolerance = 1.0e-3_real64',
    'abs(event%event_time - request%t0) >= irrigation_fixed_event_match_tolerance',
    'duration = event%depth / event%rate',
    'fluxes%surface_gross_rate = event%rate',
    'fluxes%concentration = event%concentration',
    'fluxes%subsurface_source(parameters%ssdi_first_node:parameters%ssdi_last_node) = event%rate',
    'fluxes%external_inflow_amount = sum(fluxes%subsurface_source) * active_duration',
    'candidate_state%next_fixed_event_index = event_index + 1',
    'diagnostics%status = irrigation_split_required',
    'diagnostics%split_time = event_end',
    'irrigation_time_epsilon_scale = 64.0_real64',
    'same_time = abs(a-b) <= tolerance',
    'finishes_at_event_end = same_time(request%t1, event_end)',
    'if (finishes_at_event_end) effective_t1 = event_end',
    'if (.not. same_time(committed_state%active_event_end, event_end)) then',
]
for token in required:
    assert token in process, f'missing structural fixed-event token: {token}'

forbidden = [
    'use variables', 'use mod_grid', 'use mod_irrigation', 'headcalc',
    'reference_richards', 'kernel_committed_state_t', 'kernel_candidate_state_t',
    'open(', 'close(', 'inquire(', 'read(', 'write(', 'rdinit', 'rdfdor', 'rdatim',
    'pointer ::', 'save ::', 'common /', '!$omp', 'omp_lib'
]
for token in forbidden:
    assert token not in process, f'forbidden process dependency or retained state: {token}'

# SSDI legacy concentration semantics: concentration assignment must occur only
# in the application_type < SSDI branch, after that branch begins and before else.
branch_start = process.index('if (event%application_type < irrigation_application_ssdi) then')
branch_else = process.index('else', branch_start)
concentration_pos = process.index('fluxes%concentration = event%concentration')
assert branch_start < concentration_pos < branch_else, 'SSDI must retain task-3 cirr reset value'

assert contract['translation_contract']['ssdi_depth'].startswith('legacy post-read internal irdepth after division')
assert contract['time_semantics']['legacy_event_match_tolerance_role'].startswith('management event selection only')
assert contract['time_semantics']['numerical_event_end_tolerance'].startswith('64 * epsilon(real64)')
assert 'clamped' in contract['time_semantics']['numerical_event_end_policy']
assert contract['mass_contract']['double_count_process_and_solver_mass'] is False
assert contract['hydraulic_view']['fixed_event_seam_consumes_hydraulic_view'] is False
assert contract['optional_scaling']['ssdi_array_only_when_ssdi_flux_is_active'] is True

print('FPM03_FIXED_EVENT_STATIC_ARCHITECTURE PASS')
print('FPM03_FIXED_EVENT_B110_ORACLE_BINDING PASS')
print('FPM03_FIXED_EVENT_GENERIC_TIME_POLICY PASS')
