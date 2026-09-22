# GC-RZM06E03C preregistration

**Status:** preregistered diagnostic research experiment  
**Date:** 2026-09-22  
**Production changes:** none  
**Preregistration authority:** `cc0c6629981602eeb440a66c0b7c9b6558e1ca46`

E03B showed a clear asymmetry. Full-rate bottom-first histories fail during the seventh bottom-only interval, while two top-first split histories complete. E03C therefore tests the rate hypothesis directly. It does not relax any state gate.

The C01 16 x 10 cm B01 strict Reference carrier, B01 constitutive law, dyadic `dt = 3435974 / 2^32 day`, fresh `Se=0.85` origin and `1e-12 cm` hard mass gate are unchanged.

Every non-baseline family executes:

1. ten CLOSED intervals with zero top and bottom flux;
2. a BOTTOM-only phase with `q_bottom = f*q_eq`, `q_top=0`;
3. a TOP-only phase with `q_top = f*q_eq`, `q_bottom=0`.

Here `q_eq=-K0`. The frozen grids are:

- `f=0.5`, phase lengths `n={12,14,16,18,20,22,24}`;
- `f=0.25`, phase lengths `n={24,28,32,36,40,44,48}`.

The BOTTOM and TOP phases use the same rate magnitude and the same number of intervals. A completed family therefore has exactly equal integrated top and bottom transfer. BASE_EQ remains one simultaneous equilibrium-throughflow interval.

Only fully completed strict families become candidate endpoints. Failed intervals terminate the family and must preserve the latest committed origin. No temporal subdivision, fallback, retry, tolerance change, direct state mutation or post-hoc grid extension is allowed.

Selection remains response-blind. It uses only committed node `H/theta` and the unchanged gates:

- `|ΔW_profile| <= 1e-4 cm`;
- `|ΔW_root30| <= 1e-4 cm`;
- `|ΔM1| >= 1e-2 cm`.

The same run also records the bottom-phase failure boundary by rate and cumulative removed water. This distinguishes an instantaneous-rate limitation from a mainly cumulative-state limitation. That diagnostic concerns this research construction only and is not a production solver robustness claim.

If a pair passes, it must be persisted before E04 can be preregistered. If no pair passes, E03C closes NO_MATCH without changing the frozen rate grid, phase grid, timestep or thresholds.
