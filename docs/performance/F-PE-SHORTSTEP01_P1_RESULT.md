# F-PE-SHORTSTEP01 P1 result — Newton/backtracking path localization

Date: 2026-09-26

Status: `FAILURE_LOCALIZED_TO_NEAR_TOLERANCE_LINE_SEARCH_STAGNATION`

## Result

Representative neighboring PASS/FAIL/PASS durations start from identical physical origins and identical initial nonlinear residuals.

Successful durations typically converge in 3–5 Newton iterations with one accepted full Newton update per iteration and no progress rejection.

Failed neighboring durations exhaust 48 nonlinear iterations and hundreds of backtracking attempts:

- B01 wet, +0.1 history, +0.001 cm, dt=5e-5: 48 Newton iterations, 696 trial updates, 691 progress rejects;
- O05 wet, -0.1 history, +0.001 cm, dt=1.25e-5: 48 iterations, 653 trials, 645 rejects;
- O14 wet, +0.1 history, -0.001 cm, dt=3.75e-5: 48 iterations, 263 trials, 215 rejects.

Yet their terminal residual maxima are already approximately at the compartment-balance tolerance:

- B01: Fmax = 1.0498e-12;
- O05: Fmax = 1.6431e-12;
- O14: Fmax = 8.1424e-13.

The O14 failure is especially diagnostic: Fmax is already below the 1e-12 compartment balance criterion, but the solve still exhausts the nonlinear iteration budget.

## Interpretation

The failure is not caused by an initially bad residual or a singular first Newton step.

The path reaches a near-machine/tolerance-scale residual and then remains nonconverged because another convergence condition stays active while the line-search progress rule rejects most subsequent updates.

The likely remaining gates in `headcalc` are:

- per-node pressure-head change tolerance;
- total balance tolerance;
- less likely a residual component just above the compartment threshold in the other failing cases.

The next diagnostic must report the convergence flags directly after every accepted trial, especially at the terminal failed iteration.

## Decision

Advance to P2 convergence-gate attribution.

No repair is authorized yet.