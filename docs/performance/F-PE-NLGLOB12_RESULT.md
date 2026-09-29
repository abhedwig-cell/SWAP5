# F-PE-NLGLOB12 result — above-floor endpoint robustness attribution

Date: 2026-09-29

Status:

`NLGLOB12_MIXED_ABOVE_FLOOR_ENDPOINT`

Canonical base:

`integration/f-ci-canonical@6ce07b5578c0c1193d2d21a2449a1b7788714f40`

Qualification authority:

- workflow run: `36551154824`;
- job: `109349378844`;
- conclusion: SUCCESS.

## Frozen question

Why do the 14 post-replay endpoint failures remain above the balance/storage-floor guard?

No solver behavior was changed.

## Coverage

PASS.

Exactly 14 residual endpoint failures were reproduced.

No process failures occurred.

## Frozen classification counts

- `ABOVE_FLOOR_STAGNATION`: 8;
- `ABOVE_FLOOR_STILL_DESCENDING`: 6;
- `ABOVE_FLOOR_POOR_MODEL_OSCILLATION`: 0;
- `ABOVE_FLOOR_OTHER`: 0.

No single mechanism reaches the preregistered 75% dominance gate.

Therefore:

`NLGLOB12_MIXED_ABOVE_FLOOR_ENDPOINT`.

## Interpretation

The residual population is not one homogeneous nonlinear-globalization failure.

Eight trajectories descend rapidly to a narrow above-floor plateau, with collapsed normalized head corrections and repeated small or negative full-step model quality.

Six trajectories still show a net downward residual trend at the iteration budget.

This distinction matters.

The stagnating group is a floor-neighborhood/globalization issue above the current S0 balance gate.

The descending group is compatible with an iteration-budget limitation, but NLGLOB12 does not authorize increasing MAXIT because the preregistered 75% dominance criterion was not met.

## Consequence

Do not apply one global repair to all 14 cases.

Open separate bounded successors:

1. a stagnation-subset workunit for the 8 plateau cases;
2. a descending-subset workunit for the 6 still-descending cases.

The descending subset may explicitly test additional iterations only if that experiment is preregistered and preserves unchanged mass, tolerance and route semantics.

The stagnation subset must not be rescued by MAXIT alone without evidence that additional iterations produce progress.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No tolerance, mass, MAXIT, backtracking, timestep, K-staging or route/event default change.

`LEGACY_NUMERICS` remains production default.
