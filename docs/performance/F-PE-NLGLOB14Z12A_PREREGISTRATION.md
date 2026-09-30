# F-PE-NLGLOB14Z12A preregistration — fine-RUNOFF pre-event failure attribution

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent authority:

- NLGLOB14Z12: `BLOCKED_NLGLOB14Z12_CONTROL_EXPOSURE`;
- three controls accept exact `11:16 -> 12:16` near 123.585 d;
- fine RUNOFF, dt = 6.25e-5 d, terminates before that event with `ENDPOINT_SOLVE_FAILURE`;
- accepted tail at termination remains `11:16`;
- accepted state and mass remain clean.

## Purpose

Attribute the first fine-RUNOFF pre-event endpoint-solve failure without changing the numerical or physical policy.

This workunit is diagnostic only.

## Frozen fixture

Use exactly:

- O05;
- route = RUNOFF;
- dt = 6.25e-5 d;
- horizon = 140.0 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- same persistent-KLAG control;
- same event-only state observation.

The 140 d horizon is beyond the independently exposed ~123.585 d event in the other fixtures and therefore sufficient to establish whether the blocked fine RUNOFF trajectory can reach that event without repair.

## Required diagnostics

Record:

- exact first terminal step and time;
- terminal reason;
- solver status;
- retry_advised if available;
- accepted saturated tail at failure origin;
- most recent accepted tail-change event;
- accepted-state finiteness;
- physical mass;
- dynamic-top route;
- whether failure occurs before or after the expected `11:16 -> 12:16` event window.

## Frozen classifications

If the first failure is `ENDPOINT_SOLVE_FAILURE` with solver retry advised, accepted tail `11:16`, clean rollback/state/mass and before event exposure:

`QUALIFIED_FINE_RUNOFF_PRE_EVENT_RETRY_ATTRIBUTION`.

If it is a hard non-retry solve failure:

`NLGLOB14Z12A_HARD_PRE_EVENT_SOLVE_FAILURE`.

If mass/state/geometry is invalid before failure:

`NLGLOB14Z12A_STATE_OR_MASS_INCONSISTENT`.

If the exact event is accepted before terminal failure:

`NLGLOB14Z12A_EVENT_REACHED_BEFORE_FAILURE`.

## Consequence

Only `QUALIFIED_FINE_RUNOFF_PRE_EVENT_RETRY_ATTRIBUTION` authorizes a separately preregistered Z12B transaction-safe bounded subdivision test at the failure origin.

Do not tune tolerances or forcing.

## Production boundary

Research only. No production source/default change.
