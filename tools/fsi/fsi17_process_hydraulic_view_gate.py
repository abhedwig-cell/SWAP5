#!/usr/bin/env python3
from pathlib import Path

source = Path('src/solver/mod_process_hydraulic_view.f90').read_text(encoding='utf-8')
low = source.lower()

required = [
    'type, public :: process_hydraulic_view_t',
    'active_nodes',
    'pressure_head',
    'water_content',
    'ponding_depth',
    'groundwater_level',
    'build_process_hydraulic_view',
    'validate_process_hydraulic_view',
    'use mod_soil_water_solver_contract, only: soil_water_physical_state_t',
    'type(soil_water_physical_state_t), intent(in) :: state',
]
for token in required:
    assert token.lower() in low, f'missing required view token: {token}'

forbidden = [
    'mod_reference_richards_state_binding',
    'reference_richards_state_binding_t',
    'reference_richards_legacy_workspace_t',
    'headcalc',
    'jacobian',
    'newton',
    'hm1',
    'thetm1',
    'kmean',
    'itnumb',
    'common /',
    'pointer ::',
    'save ::',
]
for token in forbidden:
    assert token not in low, f'forbidden solver-internal dependency leaked into process view: {token}'

assert low.count('\n  use ') == 1, 'process view gained an unexpected module dependency'
assert 'allocatable :: pressure_head(:)' in low
assert 'allocatable :: water_content(:)' in low
assert 'view%pressure_head = state%pressure_head' in low
assert 'view%water_content = state%water_content' in low

print('FSI17_STATIC_PROCESS_HYDRAULIC_VIEW PASS')
