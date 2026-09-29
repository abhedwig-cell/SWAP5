# F-PE-NLGLOB14N1 closeout — fine-dt saturation-entry root-trial failure attribution

Date: 2026-09-29

Final status:

`NLGLOB14N1_ROOT_TRIAL_SOLVER_FAILURE`

Canonical authority rechecked before closeout through current `integration/f-ci-canonical`.

The intervening canonical delta is ELASTIC26-only and does not alter the TIMEINT17/NLGLOB saturation-entry dependency surface.

Qualification authority:

- run `36570666847`;
- job `109413648963`;
- conclusion: SUCCESS.

## Closure

NLGLOB14N1 closes the blocker attribution.

The finest HEAD NLGLOB14N trajectory reproduces the saturation-entry blocker.

The first root-trial failure is not caused by route mismatch, predictor-state admissibility or mass inconsistency.

It is an endpoint solve failure inside the existing saturation-root bisection at a trial duration of about `1.34e-6 d`.

All route codes remain HEAD-consistent and accepted-state mass remains at roundoff scale.

## Scientific conclusion

NLGLOB14N remains blocked on coverage, not negatively classified for retreat-event convergence.

RUNOFF already satisfies the refined retreat-event convergence gate.

HEAD cannot yet test that same gate because its finest trajectory fails much earlier during saturation-entry localization.

## Direct successor

Open a separately preregistered bounded repair-attribution workunit for the fine-dt root-trial endpoint solve.

The successor should first determine whether the failure is caused by:

1. nonlinear iteration exhaustion;
2. backtracking exhaustion;
3. linear solve/Jacobian failure;
4. tolerance/representation interaction specific to the tiny root-trial substep.

Do not change MAXIT, BALTOL, route semantics, root bracketing or release semantics before that attribution.

After a qualified repair or explicit solver-policy conclusion, rerun the unchanged NLGLOB14N gate.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14N1

BASELINE: `a6e4579a98b127eb95f271e855aafe9d1e394c80`

BRANCH: `research/f-pe-nlglob14n1-fine-dt-entry-root-attribution`

STATUS: closed positive blocker attribution

TEST STATUS: focused target-fixture run PASS

QUALIFICATION STATUS: `NLGLOB14N1_ROOT_TRIAL_SOLVER_FAILURE`

NEXT SAFE STEP: preregister fine-dt root-trial endpoint-solver failure decomposition.

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
