# F-PE-NLGLOB14Z23 preregistration — repeated finite chatter strategy comparison

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Parent authority:

- Z20: finite five-change chatter after the first reverse event;
- Z21: no late recurrence until exact accepted `13:16 -> 14:16`;
- Z22: a second finite chatter burst immediately after accepted `14:16`;
- Z22 aggregate: `NLGLOB14Z22_POST14_CHATTER`;
- all observed chatter states remain finite, contiguous, mass-clean, rollback-clean and provider-valid.

## Purpose

Compare the smallest production-oriented responses to repeated finite bidirectional ownership chatter without changing the physical reference trajectory or fitting a pressure-head/water-content threshold.

Z23 is a semantics and publication study.

It does not modify production source.

## Frozen reference

The scientific reference is the exact accepted-state bidirectional trajectory from Z22 for the two fine O05 fixtures:

- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 6.25e-5 d.

The complete accepted physical trajectory and internal ownership sequence remain authoritative.

No strategy may change:

- accepted h/theta states;
- nominal time progression;
- physical mass;
- provider route;
- one-face geometry;
- internal accepted ownership used by the research solver.

## Strategies

### A — ACCEPT_AS_IS

Reference behavior.

Publish every accepted ownership change exactly as it occurs.

Record:

- publication count;
- maximum event burst length;
- longest alternating burst;
- final ownership;
- any coupling-visible reverse event.

### B — SETTLED_EVENT_PUBLICATION

Internal accepted ownership remains exactly the reference trajectory.

External ownership-event publication is non-authoritative and may be delayed within an event-local burst.

Frozen publication rule:

1. when an ownership change occurs, open a publication transaction;
2. continue the unchanged internal accepted-state trajectory;
3. close the publication transaction at the first subsequent accepted nominal interval whose ownership is unchanged from the immediately preceding accepted interval;
4. publish only the transaction origin ownership, final settled ownership, start time, settle time and number of internal ownership changes;
5. no intermediate ownership state becomes external coupling authority;
6. internal ownership remains the sole physical interface authority throughout.

This is event publication coalescing, not physical-state smoothing.

### C — COMMITTED_OWNERSHIP_CONFIRMATION_FEASIBILITY

Do not implement a fitted threshold or arbitrary dwell count.

Test whether a minimal rule that delays an opposite committed ownership move until later confirmation can be defined while preserving all of:

- accepted physical state is authority;
- each accepted physical state has exactly one valid interface ownership;
- no rejected candidate advances time;
- no physical accepted state is silently discarded;
- no duplicate interface authority;
- no fabricated intermediate state.

If retaining the old ownership after accepting a clean opposite-tail state violates exact accepted geometry, classify the simple confirmation/dwell route as semantically incompatible rather than repairing it.

## Required diagnostics

Per fixture and strategy record:

- internal ownership sequence;
- external publication sequence;
- publication count;
- burst count;
- changes per burst;
- burst duration in nominal intervals and physical time;
- final internal ownership;
- final published ownership;
- publication lag;
- whether coupling would observe reverse ownership;
- whether accepted-state authority remains unique;
- whether any physical state or time interval is suppressed;
- mass/residual/rollback/provider invariants inherited from the unchanged reference trajectory.

## Frozen classifications

### ACCEPT_AS_IS_VALID

Reference trajectory remains valid and every event is published.

### SETTLED_PUBLICATION_EQUIVALENT

Require:

- internal trajectory is identical to Z22;
- final published ownership equals final internal ownership for every burst;
- publication transactions close on the first unchanged-ownership accepted interval;
- no accepted physical state or time interval is altered;
- no duplicate physical interface authority is introduced.

### SETTLED_PUBLICATION_LOSES_REQUIRED_SEMANTICS

If coalescing hides an ownership state that is required as external coupling authority before the transaction settles, or cannot close deterministically under the frozen rule.

### SIMPLE_CONFIRMATION_SEMANTICALLY_INCOMPATIBLE

If delaying an opposite committed ownership move necessarily conflicts with the exact accepted paired saturated-tail geometry or requires rejecting/suppressing an otherwise valid accepted physical interval.

### SIMPLE_CONFIRMATION_FEASIBLE

Only if a confirmation rule can preserve every frozen authority above without a fitted threshold, hidden time advance, duplicate ownership or physical-state suppression.

Any hard mass/rollback/provider/geometry inconsistency:

`NLGLOB14Z23_REFERENCE_INCONSISTENT`.

## Frozen aggregate interpretation

If settled publication is equivalent in both fixtures and simple committed-ownership confirmation is incompatible:

`QUALIFIED_Z23_SETTLED_PUBLICATION_WITH_CONFIRMATION_FALSIFIED`.

If settled publication is equivalent and simple confirmation is also feasible:

`QUALIFIED_Z23_MULTIPLE_ANTI_CHATTER_OPTIONS`.

If settled publication loses required coupling semantics:

`NLGLOB14Z23_PUBLICATION_COALESCING_INSUFFICIENT`.

If fixtures differ materially:

`NLGLOB14Z23_MIXED_STRATEGY_RESPONSE`.

## Interpretation boundary

A positive settled-publication result would not authorize a new physical ownership state machine.

It would establish only that coupling-visible chatter can potentially be removed while preserving the exact internal accepted-state trajectory.

Production admission would still require an explicit coupling/publication contract and performance qualification.

## Stop rules

Do not:

- alter physical dt or forcing;
- alter accepted h/theta;
- tune solver tolerances;
- fit h/theta hysteresis;
- add arbitrary dwell time;
- suppress internal ownership changes;
- create a second physical interface authority;
- modify production source.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z23

BASELINE: `d276bbb7ae1cb380be68c361450bb54fe1fb75c5`

BRANCH: `research/f-pe-nlglob14z23-anti-chatter-comparison`

NEXT SAFE STEP: materialize the exact Z22 ownership-event sequences and evaluate the three frozen strategies without changing the physical trajectory.

## Production boundary

Research only. No production source/default change.
