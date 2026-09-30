# F-PE-NLGLOB14Z17A preregistration — three-fixture pre-event failure attribution

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent authority:

- NLGLOB14Z17: `BLOCKED_NLGLOB14Z17_CONTROL_EXPOSURE`;
- one control accepts exact `13:16 -> 14:16` at 514.664625 d;
- three controls terminate before event exposure with `ENDPOINT_SOLVE_FAILURE`;
- accepted state, geometry and physical mass remain clean.

## Purpose

Attribute the first pre-event endpoint-solve boundary in the three blocked Z17 controls without changing numerical or physical policy.

This workunit is diagnostic only.

## Frozen fixtures

Use exactly:

- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 1.25e-4 d;
- RUNOFF, dt = 6.25e-5 d;
- O05;
- horizon = 600.0 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- same persistent-KLAG control.

## Required diagnostics

Per fixture record:

- first terminal step and time;
- terminal reason;
- solver status;
- retry_advised flag if available;
- accepted saturated tail at failure origin;
- latest accepted tail-change event;
- finite-state status;
- physical mass;
- dynamic-top route;
- whether target `13:16 -> 14:16` was accepted before failure.

## Frozen classifications

If failure is `ENDPOINT_SOLVE_FAILURE` with retry advised, valid accepted state/mass and target not yet exposed:

`Z17A_PRE_EVENT_RETRY_ATTRIBUTED`.

If target event is accepted before terminal failure:

`Z17A_EVENT_REACHED_BEFORE_FAILURE`.

If failure is hard non-retry:

`Z17A_HARD_PRE_EVENT_SOLVE_FAILURE`.

If state/mass/geometry is invalid before terminal failure:

`Z17A_STATE_OR_MASS_INCONSISTENT`.

Aggregate positive classification if all three fixtures are clean retry-advised pre-event boundaries:

`QUALIFIED_Z17_THREE_FIXTURE_PRE_EVENT_RETRY_ATTRIBUTION`.

## Consequence

Only retry-advised, state/mass-clean attribution authorizes a separately preregistered one-level transaction-safe recovery:

`dt -> dt/2 + dt/2 -> dt`.

No tolerance tuning, forcing changes or recursive subdivision are authorized here.

## Production boundary

Research only. No production source/default change.
