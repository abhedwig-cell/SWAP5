# F-PE-NLGLOB12B closeout — bounded extra-iteration falsification

Date: 2026-09-29

Final status:

`NLGLOB12B_ITERATION_BUDGET_HYPOTHESIS_FALSIFIED`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@e59f1b2ffd97fb210c9d682332e740a1552a9f46`

Qualification authority:

- run `36552171192`;
- job `109352694286`;
- conclusion: SUCCESS.

## Closure

The hypothesis that the six NLGLOB12 still-descending cases are generally limited only by MAXIT=8 is falsified.

A fixed increase to MAXIT=16 recovers only 2/6 trajectories.

Both recovered trajectories are KLAG/O14.

All four remaining failures are TG HEAD cases.

Physical mass remains near roundoff and no process failures occur, so the negative result is numerical/mechanistic rather than a mass-safety failure.

## Consequence

Do not apply or further tune a global MAXIT increase.

The residual TG-only subset now overlaps the broader TG near-saturation temporal-admissibility line identified by NLGLOB11A.

That overlap should be investigated before opening another nonlinear-globalization repair for those four cases.

The two KLAG recoveries are retained as evidence that bounded continuation can help selected trajectories, but no production continuation policy is admitted.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB12B

BASELINE: `e59f1b2ffd97fb210c9d682332e740a1552a9f46`

BRANCH: `research/f-pe-nlglob12b-extra-iteration-falsification`

STATUS: closed negative

IMPLEMENTATION STATUS: test-only MAXIT16 falsification persisted

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `NLGLOB12B_ITERATION_BUDGET_HYPOTHESIS_FALSIFIED`

DEPENDENCIES / BLOCKERS: four TG HEAD failures remain; two KLAG trajectories recover

NEXT SAFE STEP: reconcile the four TG failures with near-saturation temporal-admissibility work; keep KLAG continuation evidence separate

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
