# F-PE-NLGLOB12 closeout — above-floor endpoint robustness attribution

Date: 2026-09-29

Final status:

`NLGLOB12_MIXED_ABOVE_FLOOR_ENDPOINT`

Canonical authority rechecked before closeout:

`integration/f-ci-canonical@2a91ef7a4ed3a211528538ba2f809993f820f300`

The intervening canonical change admits NLGLOB11 predictor research. It does not change the NLGLOB12 replay bank, HeadCalc residual equations, S0 replay semantics, balance/storage diagnostics, or classification data used here.

Qualification authority:

- run `36551154824`;
- job `109349378844`;
- conclusion: SUCCESS.

## Closure

NLGLOB12 closes the 14 above-floor endpoint failures as a mixed population.

Frozen classification counts:

- 8 `ABOVE_FLOOR_STAGNATION`;
- 6 `ABOVE_FLOOR_STILL_DESCENDING`;
- 0 `ABOVE_FLOOR_POOR_MODEL_OSCILLATION`;
- 0 `ABOVE_FLOOR_OTHER`.

No mechanism reaches the preregistered 75% dominance gate.

Final classification:

`NLGLOB12_MIXED_ABOVE_FLOOR_ENDPOINT`.

## Scientific interpretation

The remaining endpoint blocker is now split into two bounded subsets.

### Stagnation subset

Eight trajectories descend rapidly and then remain just above the current balance gate while normalized head corrections collapse to very small values.

This subset is not authorized for S0 because the unchanged balance guard remains above the admissible neighborhood.

More MAXIT is not automatically justified because the observed tail is already stagnant.

### Descending subset

Six trajectories remain above the floor but continue showing net residual decrease at the current iteration budget.

This is compatible with iteration-budget limitation, but NLGLOB12 does not authorize a MAXIT increase because the frozen dominance criterion was not met for the whole population.

## Consequence

Do not apply one repair to all 14 trajectories.

Open separate successors:

1. `F-PE-NLGLOB12A — above-floor stagnation mechanism`, restricted to the 8 stagnating cases;
2. `F-PE-NLGLOB12B — bounded extra-iteration falsification`, restricted to the 6 still-descending cases.

NLGLOB12B may test additional iterations only under preregistered limits and unchanged mass/tolerance/route semantics.

NLGLOB12A must remain observational first and must not weaken the balance gate.

The two subsets may be reunited only after their mechanisms are separately qualified.

## Preserved authority

- NLGLOB08 tail-inertness remains valid.
- NLGLOB09 S0 replay remains physically clean but incompletely recovering.
- NLGLOB10 Arm A remains valid: these 14 cases are above the S0 balance/storage guard.
- NLGLOB11 is a separate TG predictor result and does not alter this endpoint classification.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB12

BASELINE: `6ce07b5578c0c1193d2d21a2449a1b7788714f40`

CANONICAL RECONCILED THROUGH: `2a91ef7a4ed3a211528538ba2f809993f820f300`

BRANCH: `research/f-pe-nlglob12-above-floor-endpoint`

STATUS: closed mixed attribution

IMPLEMENTATION STATUS: observational diagnostics persisted

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `NLGLOB12_MIXED_ABOVE_FLOOR_ENDPOINT`

DEPENDENCIES / BLOCKERS: 8 stagnation cases and 6 still-descending cases remain separate blockers

NEXT SAFE STEP: preregister NLGLOB12A and NLGLOB12B separately

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
