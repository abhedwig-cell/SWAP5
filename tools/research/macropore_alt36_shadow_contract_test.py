#!/usr/bin/env python3
"""F-MACRO-ALT36 source contract guard for the RFM shadow runner."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SHADOW = ROOT / 'fortran' / 'mod_rfm_shadow_runner.f90'

def main():
    src = SHADOW.read_text()
    required = [
        'type, public :: rfm_shadow_reference_receipt_t',
        'logical :: available = .false.',
        'rfm_build_surface_hydraulic_input_from_state',
        "result%route = 'rfm-shadow-sidecar'",
        'if (result%reference%available) then'
    ]
    forbidden = [
        'macropore_active = .true.',
        'publish_mass',
        'commit(',
        'kernel_committed_state_t',
        'soil_water_solve_result_t'
    ]
    missing = [x for x in required if x not in src]
    present_forbidden = [x for x in forbidden if x in src]
    assert not missing, missing
    assert not present_forbidden, present_forbidden
    print('PASS F-MACRO-ALT36 shadow-runner contract')

if __name__ == '__main__': main()
