# F-PE-NLGLOB14Z2 preregistration — local transaction-safe retry subdivision

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@fb546d243c1a18481c37e5c5aa0e61d37347c95d`

Parent research authority:

- NLGLOB14Z1: `BLOCKED_NLGLOB14Z1_REFINEMENT`;
- dt=1.5625e-5 d fails reproducibly before the late 7:16 -> 8:16 retreat in both HEAD and RUNOFF;
- terminal reason is `ENDPOINT_SOLVE_FAILURE`;
- solver status is `SW_SOLVE_RETRY_ADVISED`;
- the failed trial is rolled back and physical mass remains near roundoff;
- dt=3.125e-5 d completes 2.80 d, so fixed-dt robustness is non-monotone;
- no MAXIT, BALTOL, forcing or physical-threshold change is authorized.

The canonical delta since the parent authority is ELASTIC45-only and does not alter the TIMEINT17/NLGLOB dependency surface.

## Purpose

Determine whether the first finest-dt persistent-KLAG retry request is a local interval-resolution event that can be crossed by exactly one transaction-safe subdivision:

`dt -> dt/2 + dt/2`

followed by restoration of the original nominal fixed dt.

This is a bounded mechanism test, not a general adaptive timestep policy.

## Frozen fixtures

Use only the two blocked O05 fixtures:

- HEAD, dt = 1.5625e-5 d;
- RUNOFF, dt = 1.5625e-5 d;
- horizon = 0.25 d;
- unchanged NLGLOB14N3 research policy;
- unchanged NLGLOB14G/L dry forcing;
- unchanged dynamic-top provider;
- unchanged zero bottom flux;
- unchanged solver iteration/backtracking/tolerance settings.

The horizon is long enough to pass the first known retry origins around 0.165-0.172 d and observe whether nominal-dt progress resumes.

## Frozen retry contract

At the first persistent-saturated KLAG interval returning `retry_advised`:

1. preserve the accepted origin state and accepted accounting;
2. never accept the failed nominal candidate;
3. restore the accepted origin exactly;
4. retry the same nominal interval as two consecutive half-duration KLAG transactions;
5. both half-steps must individually converge and satisfy the existing physical mass and top-boundary semantics;
6. if either half-step fails, restore the original accepted origin exactly and stop;
7. if both half-steps pass, commit the second half-step endpoint as the accepted endpoint for the original nominal interval;
8. restore the global nominal dt immediately for the next interval;
9. allow this mechanism exactly once per fixture in NLGLOB14Z2.

No recursive subdivision is permitted.

## Required diagnostics

Per fixture record:

- nominal retry step/time;
- retry_advised confirmation;
- saturated set at retry origin;
- nominal rejected-trial rollback differences;
- first half-step status, mass ledger and endpoint saturated set;
- second half-step status, mass ledger and endpoint saturated set;
- combined nominal-interval physical mass ledger;
- post-subdivision nominal-dt next interval status;
- any immediate repeated retry;
- final accepted time reached;
- dynamic-top routes;
- work counts.

## Frozen classifications

If both fixtures:

- reproduce the nominal retry;
- restore the origin exactly;
- accept both half-steps;
- close combined mass <= 5e-8 cm;
- resume at least one subsequent nominal-dt interval without immediate retry;

classify:

`QUALIFIED_LOCAL_TRANSACTION_SAFE_RETRY_SUBDIVISION`.

If half-step 1 fails in either fixture:

`NLGLOB14Z2_FIRST_HALF_RETRY_NOT_ACCEPTED`.

If half-step 1 passes but half-step 2 fails:

`NLGLOB14Z2_SECOND_HALF_RETRY_NOT_ACCEPTED`.

If both halves pass but the immediately resumed nominal interval again requests retry:

`NLGLOB14Z2_RETRY_IS_PERSISTENT_NOT_LOCAL`.

If state, accounting or physical mass leaks:

`NLGLOB14Z2_SUBDIVISION_TRANSACTION_INCONSISTENT`.

Mixed otherwise-valid route outcomes:

`NLGLOB14Z2_MIXED_LOCAL_RETRY_RESULT`.

## Interpretation boundary

A positive result only establishes that one specific finest-dt retry is locally traversable by one bounded subdivision.

It does not authorize production adaptive stepping or recursive retry.

A positive result may authorize a separately preregistered continuation test to determine whether the late 7:16 -> 8:16 event can then be reached on the repaired research trajectory.

## Stop rules

Do not:

- alter MAXIT or BALTOL;
- change forcing;
- alter physical thresholds;
- accept a retry_advised candidate;
- recursively subdivide;
- change production source.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Z2

BASELINE: `b9e7d308d252196d7b148963442facadc5f2da29`

BRANCH: `research/f-pe-nlglob14z2-local-retry-subdivision`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize one-time persistent-KLAG retry subdivision and execute the two blocked finest-dt fixtures.

## Production boundary

Research only. No production source or default policy changes.
