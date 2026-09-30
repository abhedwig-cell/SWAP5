# F-PE-NLGLOB14Z43A closeout — heterogeneous holdout reference-solvability attribution

Date: 2026-09-30

Final status:

`QUALIFIED_Z43A_REFERENCE_FAILURE_LOCALIZED`

Qualification authority:

- workflow run `36776407351`;
- job `110095310444`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z43A localizes the Z43 heterogeneous holdout blocker to the frozen full-reference nonlinear iteration ceiling.

O14/N64 fails at interval 286 and B12/N64 at interval 2276.

Both failures are:

- `SW_SOLVE_RETRY_ADVISED`;
- `legacy-reference-retry`;
- nonlinear iterations = 8;
- Jacobian builds = 8;
- linear solves = 8;
- backtracking attempts = 8;
- internal retries = 1.

Accepted-state mass remains clean before failure.

O05/N32 completes all 4,000 intervals.

## Direct successor

Open:

`F-PE-NLGLOB14Z43B — production/legacy nonlinear-iteration authority audit`.

The successor must determine the already-admitted production/legacy MAXIT policy and compare it with the Z43 research choice `max_iterations=8`.

Do not infer or tune a new ceiling from the failed fixtures.

If maxit=8 is not the production authority, a revised production-admission holdout may use the actual admitted configuration in a separately preregistered workunit.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z43A

BRANCH: `research/f-pe-nlglob14z43a-holdout-reference-solvability`

RESULT POSTIMAGE BEFORE CLOSEOUT: `7b72d8e341fa0f242ad4d1ce3664c0c29c9756f3`

QUALIFICATION STATUS: `QUALIFIED_Z43A_REFERENCE_FAILURE_LOCALIZED`

NEXT SAFE STEP: production/legacy nonlinear-iteration authority audit.

## Production boundary

No production default change.
