# F-PE-NLGLOB14Z14A preregistration — three-fixture pre-event failure attribution

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent authority:

- NLGLOB14Z14: `BLOCKED_NLGLOB14Z14_CONTROL_EXPOSURE`;
- coarse HEAD dt=1.25e-4 accepts exact `12:16 -> 13:16` at 260.961125 d;
- the other three controls terminate with `ENDPOINT_SOLVE_FAILURE` before aggregate event qualification;
- accepted state, geometry and physical mass remain clean at their terminal origins.

## Purpose

Attribute the first pre-event endpoint-solve failure in each of the three blocked Z14 controls without changing numerical or physical policy.

Diagnostic only. No recovery is permitted.

## Frozen fixtures

Use exactly:

1. HEAD, dt = 6.25e-5 d;
2. RUNOFF, dt = 1.25e-4 d;
3. RUNOFF, dt = 6.25e-5 d.

For all:

- O05;
- horizon = 300.0 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- unchanged persistent-KLAG control;
- same event-only accepted-state observation.

## Required diagnostics

Per fixture record:

- exact first terminal step;
- terminal time;
- terminal reason;
- solver status;
- retry_advised flag if available;
- accepted saturated tail at failure origin;
- most recent accepted tail-change event;
- whether `12:16 -> 13:16` was already accepted;
- accepted-state finiteness;
- physical mass;
- dynamic-top route.

## Frozen classifications

If terminal reason is `ENDPOINT_SOLVE_FAILURE`, solver status requests retry, accepted state/mass/geometry are clean, and event is not yet accepted:

`QUALIFIED_Z14A_PRE_EVENT_RETRY_ATTRIBUTION`.

If event is accepted before terminal failure:

`NLGLOB14Z14A_EVENT_REACHED_BEFORE_FAILURE`.

If solver failure is hard/non-retry:

`NLGLOB14Z14A_HARD_PRE_EVENT_SOLVE_FAILURE`.

Any state/mass/geometry inconsistency:

`NLGLOB14Z14A_STATE_OR_MASS_INCONSISTENT`.

## Aggregate interpretation

If all three blocked fixtures classify `QUALIFIED_Z14A_PRE_EVENT_RETRY_ATTRIBUTION`:

`QUALIFIED_Z14A_THREE_FIXTURE_RETRY_ATTRIBUTION`.

Otherwise retain the per-fixture classifications; do not repair anything in Z14A.

## Consequence

Only retry-advised, clean fixtures may proceed to separately preregistered transaction-safe bounded subdivision recovery.

No tolerance tuning or forcing change is authorized.

## Production boundary

Research only. No production source/default change.
