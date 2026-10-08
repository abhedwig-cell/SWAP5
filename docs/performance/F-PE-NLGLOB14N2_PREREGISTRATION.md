# F-PE-NLGLOB14N2 preregistration — fine-dt root-trial endpoint-solver decomposition

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@12e12538f043c6716086615ea51c8b87610600c4`

Parent authority:

- NLGLOB14N: `BLOCKED_NLGLOB14N_REFINED_RETREAT_CONVERGENCE`;
- NLGLOB14N1: `NLGLOB14N1_ROOT_TRIAL_SOLVER_FAILURE`.

## Purpose

NLGLOB14N1 established that the finest HEAD trajectory fails during saturation-entry root localization because one root-trial endpoint solve returns `ENDPOINT_SOLVE_FAILURE` at a trial duration of about `1.34e-6 d`.

NLGLOB14N2 decomposes that solver failure using existing solver diagnostics only.

No numerical control is changed.

## Frozen target fixture

Exactly:

- O05;
- TG;
- HEAD;
- dt = `7.8125e-6 d`;
- horizon = `0.05 d`;
- unchanged forcing;
- unchanged root bisection;
- unchanged numerical configuration:
  - max nonlinear iterations = 8;
  - max backtracking attempts = 8;
  - existing balance/head/ponding tolerances.

## Frozen diagnostics

At the first endpoint solve failure inside a saturation-root trial record:

- step;
- root iteration and trial dt;
- solver status;
- solver diagnostic route;
- nonlinear iterations;
- backtracking attempts;
- Jacobian builds;
- linear solves;
- internal retries;
- alternative solver calls;
- whether retry was advised.

Also retain the NLGLOB14N1 route-consistency and pre-failure mass evidence.

## Frozen classifications

### NONLINEAR_ITERATION_LIMIT

Classify if the failing solve reaches the configured maximum nonlinear-iteration count and no more specific linear/backtracking failure signal is present.

### BACKTRACKING_LIMIT

Classify if backtracking attempts reach the configured maximum and the solve fails without a separate linear-solver failure signal.

### LINEAR_OR_JACOBIAN_FAILURE

Classify if diagnostics show a failed/incomplete linear/Jacobian route inconsistent with ordinary nonlinear exhaustion, or the solver diagnostic route explicitly identifies such a failure.

### RETRY_ADVISED_AT_ROOT_TRIAL

Classify if the reference solver returns retry-advised semantics for the trial rather than a hard failed workspace/type/contract result.

### ROOT_TRIAL_SOLVER_FAILURE_OTHER

Classify if failure reproduces but none of the above mechanisms is supported.

### BLOCKER_NOT_REPRODUCED

Classify if the frozen target no longer reproduces the NLGLOB14N1 endpoint failure.

## Consequence

NLGLOB14N2 is attribution only.

No repair is authorized inside this workunit.

A follow-up may test exactly one preregistered repair hypothesis only after this decomposition is complete. MAXIT, BALTOL, backtracking limits, root bracketing and release semantics remain frozen here.

## Stop rules

Do not:

- increase nonlinear iterations;
- increase backtracking;
- relax balance/head/ponding tolerances;
- change dt or forcing;
- change root bracketing;
- introduce fallback;
- change release/event semantics.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

Expected effect: diagnostics only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14N2

BASELINE: `12e12538f043c6716086615ea51c8b87610600c4`

BRANCH: `research/f-pe-nlglob14n2-root-trial-solver-decomposition`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: expose existing solve diagnostics at the first root-trial endpoint failure and classify the failure mechanism.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
