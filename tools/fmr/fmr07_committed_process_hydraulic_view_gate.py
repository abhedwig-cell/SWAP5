#!/usr/bin/env python3
from pathlib import Path

binding = Path('src/runtime/mod_fmr_process_hydraulic_view_binding.f90').read_text(encoding='utf-8').lower()
view = Path('src/solver/mod_process_hydraulic_view.f90').read_text(encoding='utf-8').lower()

required_binding = [
    'type(kernel_committed_state_t), intent(in) :: committed',
    'call committed%snapshot(snapshot, available)',
    'type is (fmr_b110_physical_state_t)',
    'type(soil_water_physical_state_t) :: state',
    'call build_process_hydraulic_view(state, view, ok)',
    'state%pressure_head = physical%pressure_head',
    'state%water_content = physical%water_content',
    'state%ponding_depth = physical%ponding_depth',
    'state%groundwater_level = physical%groundwater_level',
]
for token in required_binding:
    assert token in binding, f'missing committed-view binding token: {token}'

forbidden_binding = [
    'kernel_candidate_state_t',
    'kernel_checkpoint_t',
    'reference_richards_state_binding_t',
    'mod_reference_richards_state_binding',
    'reference_richards_legacy_workspace_t',
    'headcalc',
    'jacobian',
    'newton',
    'workspace',
    'hm1',
    'thetm1',
    'kmean',
    'itnumb',
    'snow%',
    'commit_candidate',
    'rollback_candidate',
]
for token in forbidden_binding:
    assert token not in binding, f'forbidden runtime dependency or mutation surface: {token}'

assert 'pointer ::' not in binding, 'runtime view binding must not expose pointer aliases'
assert 'save ::' not in binding, 'runtime view binding must not retain persistent state'
assert 'type(kernel_committed_state_t)' not in view, 'F-SI17 view must remain transaction-neutral'
assert 'pointer ::' not in view, 'F-SI17 view must remain detached'

print('FMR07_STATIC_COMMITTED_VIEW_BINDING PASS')
