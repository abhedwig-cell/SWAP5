# F-PE-NLGLOB14Z17D preregistration — fine-RUNOFF second-retry attribution

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`

Parent authority:

- NLGLOB14Z17C is blocked only by a second fine-RUNOFF retry before target event;
- first known fine-RUNOFF retry at 71.1821875 d is already qualified and locally recoverable;
- after that recovery, fine RUNOFF reaches a second terminal interval at 348.0423125 d;
- accepted tail at that origin remains `13:16`;
- state, geometry and mass remain valid.

## Purpose

Attribute the second fine-RUNOFF terminal interval without repairing it.

## Frozen fixture

Use exactly:

- O05;
- route = RUNOFF;
- nominal dt = 6.25e-5 d;
- horizon = 360.0 d;
- unchanged forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- first known retry at 71.1821875 d repaired exactly once by the already-qualified `dt/2 + dt/2` policy;
- no repair allowed at the second terminal interval.

## Required diagnostics

At the second terminal interval record:

- exact step and time;
- terminal reason;
- solver status;
- retry_advised;
- accepted saturated tail at origin;
- exact rollback/state preservation;
- state finiteness;
- physical mass;
- dynamic-top route;
- whether target `13:16 -> 14:16` has already occurred.

## Frozen classifications

If the second terminal interval is `ENDPOINT_SOLVE_FAILURE`, solver status requests retry, target event has not occurred, and accepted state/mass/geometry remain clean:

`QUALIFIED_Z17D_SECOND_RETRY_ATTRIBUTION`.

If the target event is accepted before the second failure:

`Z17D_EVENT_REACHED_BEFORE_SECOND_RETRY`.

If the second solve failure is hard/non-retry:

`Z17D_HARD_SECOND_SOLVE_FAILURE`.

Any state/mass/rollback inconsistency:

`Z17D_SECOND_RETRY_STATE_OR_MASS_INCONSISTENT`.

## Consequence

Only `QUALIFIED_Z17D_SECOND_RETRY_ATTRIBUTION` authorizes a separately preregistered test of one additional local transaction recovery at the second retry origin.

No recursive subdivision, tolerance tuning, forcing change or event fitting is authorized.

## Production boundary

Research only. No production source/default change.
