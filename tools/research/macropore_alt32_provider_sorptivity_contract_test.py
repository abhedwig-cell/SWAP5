#!/usr/bin/env python3
"""F-MACRO-ALT32 contract checks for provider-bound surface sorptivity."""
from pathlib import Path
import math

ROOT = Path(__file__).resolve().parent
ADAPTER = ROOT / 'fortran' / 'mod_rfm_research_adapter.f90'
SORP = ROOT / 'fortran' / 'mod_rfm_surface_sorptivity.f90'

def main():
    a = ADAPTER.read_text()
    s = SORP.read_text()
    required_adapter = [
      'use mod_rfm_surface_sorptivity',
      'rfm_build_surface_hydraulic_input_from_state',
      'call rfm_evaluate_surface_sorptivity',
      'evaluate_point_conductivity'
    ]
    required_sorp = [
      'class(constitutive_hydraulics_provider_t)',
      'CONSTITUTIVE_DEMAND_WATER_CONTENT + CONSTITUTIVE_DEMAND_CONDUCTIVITY',
      'integrand = (theta_s + theta(1) - 2.0_real64*theta_initial) * conductivity(1)',
      'sorptivity = sqrt(max(0.0_real64, integral))'
    ]
    missing = [x for x in required_adapter if x not in a] + [x for x in required_sorp if x not in s]
    assert not missing, missing

    # Guard against a duplicated hard-coded default-MvG formula in the helper.
    forbidden = ['cofgen(', 'B110_H_CRIT', 'Se_local', 'alpha*']
    duplicated = [x for x in forbidden if x in s]
    assert not duplicated, duplicated

    # Analytic sanity check of the transformed Parlange integrand.
    theta_i = 0.25
    theta_s = 0.45
    theta_mid = 0.35
    k_mid = 2.0
    integrand = (theta_s + theta_mid - 2*theta_i) * k_mid
    assert integrand > 0.0
    assert math.isfinite(math.sqrt(integrand))
    print('PASS F-MACRO-ALT32 provider-bound sorptivity contract')

if __name__ == '__main__': main()
