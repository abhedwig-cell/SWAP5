# F-PE-NLGLOB14Z7 confirmatory preregistration — control retreat 9:16 -> 10:16

Date: 2026-09-29

Status: `CONFIRMATORY_PREREGISTERED_BEFORE_NEW_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authority:

- NLGLOB14Z4: qualified control retreat `8:16 -> 9:16` near 7.65 d;
- NLGLOB14Z6: qualified split ownership through `8:16 -> 9:16`;
- an earlier Z4 diagnostic run to 25.6 d incidentally ended with saturated tail `10:16`;
- that incidental observation was not preregistered as a `9:16 -> 10:16` qualification and is not itself authority for the next event.

## Purpose

Run a new confirmatory control exposure with a frozen exact event gate for:

`9:16 -> 10:16`.

This workunit is explicitly confirmatory rather than blind discovery.

## Frozen fixtures

Use O05 persistent saturated-KLAG control:

- HEAD and RUNOFF;
- dt = 6.25e-5 d;
- dt = 3.125e-5 d;
- fixed horizon = 25.60 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- physical mass as hard authority.

The dt=3.125e-5 level provides a new independent refinement level for this event.

## Event definition

Qualification requires an accepted contiguous saturated-tail transition exactly:

`nodes 9:16 -> nodes 10:16`.

Both states are defined only by:

- `h >= 0`;
- `theta == theta_s`.

No predictor crossing, pressure threshold, theta epsilon, interpolation, extrapolation or count-only trigger is allowed.

## Instrumentation

Use accepted-state event-only logging.

Instrumentation may reduce output volume but may not alter solver path, accepted state, forcing, timestep, provider semantics or accounting.

## Hard gates

Per fixture:

- complete 25.60 d trajectory;
- finite accepted states;
- physical interval and cumulative mass valid;
- exact accepted `9:16 -> 10:16`;
- contiguous saturated tail;
- no reverse expansion after the qualified 9:16 state;
- no skipped node.

## Frozen classifications

If all four fixtures expose exact accepted `9:16 -> 10:16` and remain valid:

`QUALIFIED_CONFIRMATORY_RETREAT_9_TO_10_CONTROL`.

If all four remain valid but do not reach the event:

`NLGLOB14Z7_RETREAT_9_TO_10_NOT_REACHED`.

If route/dt outcomes differ:

`NLGLOB14Z7_MIXED_CONFIRMATORY_EXPOSURE`.

Any reverse/skipped/noncontiguous state:

`NLGLOB14Z7_CONFIRMATORY_STATE_INCONSISTENT`.

Any process/mass failure:

`BLOCKED_NLGLOB14Z7_CONFIRMATORY_CONTROL`.

## Consequence

Positive Z7 authorizes a separately preregistered split ownership test through:

`9:16 -> 10:16`

with ownership:

`face 8/9 -> face 9/10`.

It does not qualify later retreats, disappearance or whole-column TG re-entry.

## Production boundary

Research only. No production source/default change.
