# F-PE-NLGLOB14Z2 preregistration — local persistent-KLAG retry subdivision attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b6c9079c209eb6d1fe2db2fd61ff330941770166`

Parent research authority:

- NLGLOB14Z1: `BLOCKED_NLGLOB14Z1_REFINEMENT`;
- dt = 1.5625e-5 d fails reproducibly before the late retreat:
  - HEAD near 0.171609375 d;
  - RUNOFF near 0.16509375 d;
- terminal mechanism is `ENDPOINT_SOLVE_FAILURE` with `SW_SOLVE_RETRY_ADVISED`;
- accepted origin remains finite, mass-clean and on surface-flux dry forcing;
- HeadCalc restores accepted state and requests timestep reduction;
- no MAXIT/BALTOL/forcing change is authorized.

## Purpose

Determine whether the first finest-dt persistent-KLAG retry request is a local transaction-recoverable interval or a persistent inability to advance.

Question:

after the first nominal persistent-KLAG interval returns `retry_advised`, does exact rollback followed by two half-dt KLAG subintervals recover the original nominal time window?

## Frozen fixtures

Use only the two blocked O05 fixtures:

- route HEAD;
- route RUNOFF;
- nominal dt = `1.5625e-5 d`;
- horizon long enough to include the first known retry origin, fixed at `0.18 d`;
- unchanged NLGLOB14N3 root-controller policy;
- unchanged NLGLOB14G dry forcing;
- unchanged zero bottom flux.

## Frozen retry semantics

At the first persistent-saturated KLAG endpoint solve that returns `retry_advised`:

1. record the nominal failure;
2. do not accept its candidate;
3. restore exactly:
   - accepted physical state;
   - reference workspace;
   - cumulative physical mass ledger;
   - cumulative runoff;
   - max-ledger authority;
   - eligible/terminal/transition state;
4. set temporary retry dt to exactly `0.5 * dt_nominal`;
5. execute one ordinary persistent-KLAG half interval;
6. if accepted, execute a second ordinary persistent-KLAG half interval;
7. restore nominal dt after the two-half window;
8. continue the nominal trajectory to the frozen 0.18 d horizon if the window was recovered.

No recursive subdivision is allowed in Z2.

If either half returns retry, classify it rather than subdividing again.

## Required diagnostics

For each route record:

- nominal failure step and terminal reason;
- retry_advised flag;
- accepted saturated set at retry origin;
- rollback differences:
  - h;
  - theta;
  - ponding;
  - cumulative ledger;
  - cumulative runoff;
- first-half status, solver status, retry flag and accepted saturated set;
- second-half equivalent diagnostics;
- whether both halves sum exactly to one nominal dt;
- whether nominal execution resumes afterward;
- whether another retry occurs before 0.18 d;
- physical mass;
- final accepted state finiteness.

## Frozen classifications

### LOCAL_HALFSTEP_RECOVERS_NOMINAL_WINDOW

Require:

- nominal retry reproduced;
- exact rollback;
- both half intervals accepted;
- no recursive retry;
- one nominal time window recovered;
- accepted mass/state valid.

### LOCAL_HALFSTEP_RECOVERS_BUT_RETRY_RECURS

As above, but a later nominal interval before 0.18 d again returns retry_advised.

### FIRST_HALF_STILL_RETRY_ADVISED

The first half interval also requests retry.

### SECOND_HALF_RETRY_ADVISED

The first half is accepted but the second half requests retry.

### LOCAL_RETRY_HARD_FAILURE

A half interval fails for a non-retry reason.

### LOCAL_RETRY_TRANSACTION_INCONSISTENT

Any rollback, state, time-window or physical-mass inconsistency.

## Frozen aggregate interpretation

If both routes recover the nominal window and complete 0.18 d without another retry:

`QUALIFIED_LOCAL_PERSISTENT_KLAG_RETRY_RECOVERY`.

If both recover the first window but retry recurs before 0.18 d:

`NLGLOB14Z2_LOCAL_RECOVERY_WITH_RECURRENT_RETRY`.

If both fail at first half with retry:

`NLGLOB14Z2_HALFSTEP_INSUFFICIENT`.

If route outcomes differ without transaction inconsistency:

`NLGLOB14Z2_MIXED_LOCAL_RETRY_RECOVERY`.

Any transaction inconsistency:

`NLGLOB14Z2_RETRY_TRANSACTION_INCONSISTENT`.

## Interpretation boundary

A positive result establishes only local retry recoverability at the first Z1 finest-dt failure.

It does not by itself qualify adaptive retry for the entire late-horizon control trajectory.

A recurrent retry result authorizes bounded retry-depth attribution, not tolerance tuning.

## Stop rules

Do not:

- change retry scale from 0.5;
- recurse below one halfstep in Z2;
- change MAXIT or BALTOL;
- change forcing;
- change physical thresholds;
- modify production source.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Z2

BASELINE: `b9e7d308d252196d7b148963442facadc5f2da29`

BRANCH: `research/f-pe-nlglob14z2-local-klag-retry`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: inject first-retry transactional halfstep recovery into the persistent-KLAG research wrapper and run the two frozen fixtures.

## Production boundary

Research only. No production source or default policy changes.
