# F-PE-BALTOL01 P2R result — terminal-flux refinement exception

Date: 2026-09-26

Status: `ORACLE_REFINEMENT_CONFIRMED`

## Target

B01 wet, dynamic history +0.1, prescribed-head offset -0.01 cm.

## Result

All N=16, 32 and 64 fixed-substep Reference oracle levels complete under:

`tol_rate = max(1e-12 cm/day, 2.8e-16 cm / dt_sub)`.

Refinement differences contract from 16→32 to 32→64:

- max |dh|: 2.22369e-4 → 1.12023e-4 cm;
- max |dtheta|: 4.24281e-7 → 2.13743e-7;
- terminal bottom-flux difference: 5.36764e-5 → 4.29189e-5 cm/day;
- integrated bottom-exchange difference: 1.48336e-8 → 8.74276e-9 cm.

N=64 maximum per-substep mass residual is 3.39e-21 cm.

## Interpretation

The apparent P2 terminal-flux monotonicity exception was caused by an anomalously small 8→16 flux difference, not by loss of convergence at finer resolution.

The 16→32→64 sequence contracts consistently across state, flux and integrated exchange.

## Decision

The DEPTH_2P8E16 scaled balance floor restores a usable, convergent independent fixed-substep Reference oracle for the BALTOL01/TEMPORAL03 qualification domain.

No production source change is authorized by P2R alone.