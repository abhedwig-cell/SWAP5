# F-PE-NLGLOB12B result — bounded extra-iteration falsification

Date: 2026-09-29

Status:

`NLGLOB12B_ITERATION_BUDGET_HYPOTHESIS_FALSIFIED`

Canonical base:

`integration/f-ci-canonical@e59f1b2ffd97fb210c9d682332e740a1552a9f46`

Qualification authority:

- workflow run: `36552171192`;
- job: `109352694286`;
- conclusion: SUCCESS.

## Frozen question

Are the six NLGLOB12 `ABOVE_FLOOR_STILL_DESCENDING` trajectories failing only because the nonlinear iteration budget of 8 is too small?

The frozen falsification changed only:

`MAXIT: 8 -> 16`.

S0 replay, tolerances, backtracking, timestep, K staging, route physics and mass authority remained unchanged.

## Result

Completed requested horizon:

`2 / 6`.

Recovered:

- O14 / KLAG / HEAD / dt 6.25e-5 d;
- O14 / KLAG / RUNOFF / dt 3.125e-5 d.

Still failing with `ENDPOINT_SOLVE_FAILURE`:

- B12 / TG / HEAD / dt 1.25e-4 d;
- O05 / TG / HEAD / dt 3.125e-5 d;
- O14 / TG / HEAD / dt 6.25e-5 d;
- O14 / TG / HEAD / dt 3.125e-5 d.

All completed trajectories remain finite.

Physical mass remains near roundoff:

- max interval ledger about `2.84e-14 cm`;
- max cumulative ledger about `1.69e-14 cm`.

No process failure occurred.

## Frozen classification

Because only 2/6 complete, the preregistered <=3/6 negative gate applies:

`NLGLOB12B_ITERATION_BUDGET_HYPOTHESIS_FALSIFIED`.

## Interpretation

The six cases were still descending at MAXIT=8, but that did not imply that a modest fixed increase in Newton iterations would generally solve them.

The two KLAG O14 cases recover.

All four remaining failures are TG HEAD cases.

Therefore a global MAXIT increase is not supported as the repair.

The residual descending subset itself separates by temporal mode after the falsification.

## Consequence

Do not test additional fixed MAXIT values inside NLGLOB12B.

The four remaining TG cases should be reconciled with the separate TG near-saturation/temporal-admissibility line.

The two recovered KLAG cases may inform a later bounded-cost continuation policy, but they do not justify changing the global production iteration budget.

## Production boundary

Research only.

No production `src/**` change.

No tolerance, mass, timestep, K-staging, route/event or production MAXIT change.

`LEGACY_NUMERICS` remains production default.
