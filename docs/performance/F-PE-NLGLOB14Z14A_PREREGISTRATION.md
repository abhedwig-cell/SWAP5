# F-PE-NLGLOB14Z14A preregistration — three-fixture pre-event failure attribution

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent authority:

- NLGLOB14Z14: `BLOCKED_NLGLOB14Z14_CONTROL_EXPOSURE`;
- coarse HEAD accepts exact `12:16 -> 13:16` at 260.961125 d;
- three other controls terminate with `ENDPOINT_SOLVE_FAILURE` before target-event exposure;
- accepted state, geometry and physical mass remain clean up to those failures.

## Purpose

Attribute the first pre-event endpoint-solve failure in each of the three blocked Z14 control fixtures without changing numerical or physical policy.

Diagnostic only. No repair is permitted in Z14A.

## Frozen fixtures

Use exactly:

1. HEAD, dt = 6.25e-5 d;
2. RUNOFF, dt = 1.25e-4 d;
3. RUNOFF, dt = 6.25e-5 d;

with:

- O05;
- horizon = 280.0 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- unchanged persistent-KLAG control;
- same event-only accepted-state observation.

The horizon exceeds the independently exposed coarse-HEAD event at 260.961125 d and is sufficient to distinguish pre-event failure from accepted target-event exposure.

## Required diagnostics

Per fixture record:

- first terminal step and time;
- terminal reason;
- solver status;
- retry_advised flag;
- accepted saturated tail at failure origin;
- last accepted tail-change event;
- whether target `12:16 -> 13:16` was accepted before failure;
- state finiteness;
- physical mass;
- accepted geometry consistency.

## Frozen fixture classifications

If first failure is `ENDPOINT_SOLVE_FAILURE`, solver requests retry, target event has not occurred, and accepted state/mass/geometry are clean:

`Z14A_PRE_EVENT_RETRY_ATTRIBUTED`.

If the event is accepted before failure:

`Z14A_EVENT_REACHED_BEFORE_FAILURE`.

If endpoint solve failure is hard/non-retry:

`Z14A_HARD_PRE_EVENT_SOLVE_FAILURE`.

If accepted state, geometry or mass is inconsistent:

`Z14A_STATE_OR_MASS_INCONSISTENT`.

## Frozen aggregate classifications

If all three fixtures classify `Z14A_PRE_EVENT_RETRY_ATTRIBUTED`:

`QUALIFIED_Z14_THREE_FIXTURE_PRE_EVENT_RETRY_ATTRIBUTION`.

If outcomes are otherwise valid but mixed:

`NLGLOB14Z14A_MIXED_FAILURE_ATTRIBUTION`.

Any hard failure:

`NLGLOB14Z14A_HARD_FAILURE_BOUNDARY`.

Any state/mass inconsistency:

`NLGLOB14Z14A_STATE_OR_MASS_INCONSISTENT`.

## Consequence

Only retry-advised, state/mass-clean fixtures may proceed to separately preregistered transaction-safe bounded subdivision.

No tolerance tuning, forcing change or physical-threshold change is authorized.

## Production boundary

Research only. No production source/default change.
