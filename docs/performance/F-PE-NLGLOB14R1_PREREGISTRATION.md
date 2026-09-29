# F-PE-NLGLOB14R1 preregistration — post-handoff second-interval endpoint failure attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

current `integration/f-ci-canonical` at preregistration.

Reconciliation note:

The current canonical delta since the inherited NLGLOB research base contains no TIMEINT/NLGLOB14, HeadCalc, default-MvG, dynamic-top or Reference-Richards dependency change. This workunit therefore retains the exact NLGLOB14R scientific postimage and changes diagnostics only.

Parent research authority:

- NLGLOB14Q: `NLGLOB14Q_FULL_COLUMN_TG_SHADOW_HANDOFF_ADMISSIBLE`;
- NLGLOB14R: `NLGLOB14R_MIXED_HANDOFF_PERSISTENCE`.

## Purpose

NLGLOB14R established a uniform two-stage pattern:

1. the first TG interval after first-retreat handoff is accepted in all 12 fixtures;
2. the immediately following TG interval fails in all 12 with harness-level terminal reason `ENDPOINT_SOLVE_FAILURE`;
3. no saturation-mode re-entry occurs before that failure;
4. accepted state and mass remain valid.

NLGLOB14R1 attributes the second-interval failure without changing solver or mode policy.

## Frozen fixtures

Use exactly the 12 NLGLOB14R fixtures:

- O05;
- HEAD and RUNOFF wet-entry families;
- dt = 2.5e-4 through 7.8125e-6 d;
- same first-retreat handoff;
- first TG interval accepted exactly as in NLGLOB14R;
- same dry forcing and surface-flux release route;
- same second TG interval.

## Frozen diagnostics

At the second-interval failure record the existing TG-stage and solver diagnostics before the harness-level terminal reason obscures them:

- whether failure occurs before or after endpoint solve invocation;
- origin route;
- predictor route;
- solver status;
- retry advised;
- solver diagnostic route;
- nonlinear iterations;
- backtracking attempts;
- Jacobian builds;
- linear solves;
- internal retries;
- alternative solver calls;
- endpoint route if available;
- accepted route if available;
- domain-failure flag;
- state finiteness;
- accepted interval/cumulative mass before the failed attempt.

No candidate from the failing second interval is accepted.

## Frozen fixture classifications

### SECOND_INTERVAL_RETRY_ADVISED

Classify if the endpoint solver returns retry-advised semantics.

### SECOND_INTERVAL_SOLVER_HARD_FAILURE

Classify if the endpoint solver returns a non-converged, non-retry hard failure.

### SECOND_INTERVAL_PREDICTOR_OR_DOMAIN_FAILURE

Classify if failure occurs before a successful endpoint solve through predictor or TG-domain admissibility.

### SECOND_INTERVAL_ROUTE_FAILURE

Classify if a converged solve is rejected by predictor/endpoint/accepted route inconsistency.

### SECOND_INTERVAL_FAILURE_UNATTRIBUTED

Classify if the NLGLOB14R failure reproduces but none of the above mechanisms can be established.

### BLOCKER_NOT_REPRODUCED

Classify if the frozen NLGLOB14R second-interval failure no longer reproduces.

## Frozen aggregate interpretation

If 12/12 classify `SECOND_INTERVAL_RETRY_ADVISED`:

`NLGLOB14R1_UNIFORM_SECOND_INTERVAL_RETRY_ADVISED`.

If 12/12 share another single fixture classification, report the corresponding uniform mechanism.

Otherwise:

`NLGLOB14R1_MIXED_SECOND_INTERVAL_FAILURE_MECHANISM`.

Any state or accepted-mass inconsistency is a blocker, not a solver classification.

## Consequence

NLGLOB14R1 is attribution only.

A repair hypothesis may be opened only after the uniform or mixed failure mechanism is established. Do not infer that the accepted first-retreat TG handoff itself is invalid merely because its following interval requests retry.

## Stop rules

Do not:

- increase MAXIT or backtracking;
- relax BALTOL/head/ponding tolerances;
- change dt, forcing or provider capacity;
- change first-retreat release timing;
- suppress saturation-event re-entry;
- add hysteresis;
- accept a failed second-interval candidate;
- modify production source.

## Architecture invariants

Affected invariants: 2, 3, 4, 7, 9, 13, 20, 23, 25, 26, 30.

Expected effect: diagnostics only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14R1

BRANCH: `research/f-pe-nlglob14r1-second-interval-failure-attribution`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: expose existing second-interval TG/solver diagnostics on the frozen 12-case NLGLOB14R window.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
