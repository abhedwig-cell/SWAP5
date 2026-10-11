# F-PE-SHORTSTEP01 P3 result — balance-tolerance floor qualification

Date: 2026-09-26

Status: `TOLERANCE_FLOOR_CAUSALITY_CONFIRMED`

## Protocol

Three representative failing short-duration targets and their nearest successful duration controls were rerun while changing only compartment and total balance tolerances together:

- 1e-12;
- 2e-12;
- 5e-12;
- 1e-11;
- 1e-10.

Head tolerances, physical state, forcing, dt, solver caps and all other numerical controls were unchanged.

## Result

Every fail target at 1e-12 becomes a successful solve at 2e-12.

### B01 wet, +0.1 history, +0.001 cm, dt=5e-5

- 1e-12: FAIL, 48 Newton, 696 backtracking attempts;
- 2e-12: PASS, 3 Newton, 3 backtracking attempts;
- all looser tested tolerances: same accepted terminal state and flux as 2e-12.

### O05 wet, -0.1 history, +0.001 cm, dt=1.25e-5

- 1e-12: FAIL, 48 Newton, 653 backtracking attempts;
- 2e-12: PASS, 6 Newton, 7 backtracking attempts;
- 5e-12 and looser: 3–4 Newton iterations;
- maximum terminal-state difference among successful tolerance arms is about 3.6e-14 cm in head and 5.6e-17 in water content;
- terminal-flux difference is at most about 8.9e-12 cm/day.

### O14 wet, +0.1 history, -0.001 cm, dt=3.75e-5

- 1e-12: FAIL, 48 Newton, 263 backtracking attempts;
- 2e-12: PASS, 4 Newton, 4 backtracking attempts;
- all looser tested tolerances produce the same accepted terminal state and flux.

### Successful controls

All nearest successful neighboring durations remain successful across the tolerance sweep.

Their accepted states are identical or differ only at floating-point scale.

## Interpretation

The P0 non-monotone dt failure bands are caused by the absolute 1e-12 balance-convergence floor in the research fixture.

At that setting the solver can reach a physically stable near-root state, miss one absolute balance test by O(1e-15 to 1e-12), and then spend the remaining nonlinear budget in line-search stagnation.

A minimal factor-two relaxation removes the failure without a material change in accepted state or flux on all representative targets.

This invalidates the earlier interpretation of a generic short-duration Reference Richards instability.

The behavior is instead a tolerance-policy pathology exposed by an unusually strict balance setting.

## Decision

SHORTSTEP01 has localized the mechanism sufficiently.

No production source repair is made here.

Open a separate qualification workunit for a principled Reference Richards balance-tolerance floor and its effect on exact/reference authority, mass error and performance.
