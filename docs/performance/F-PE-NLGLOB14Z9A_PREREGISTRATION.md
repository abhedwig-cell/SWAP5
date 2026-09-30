# F-PE-NLGLOB14Z9A preregistration — confirmatory retreat 10:16 -> 11:16 control

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent authority:

- NLGLOB14Z9 is blocked under its 102.4 d aggregate contract because one fine RUNOFF fixture fails after the accepted event;
- all four Z9 fixtures nevertheless expose exact accepted `10:16 -> 11:16` near 53.99 d before any failure;
- event state is contiguous, non-skipping, non-reversing and mass-clean;
- downstream split ownership is not yet authorized from Z9.

## Purpose

Confirm the already exposed physical retreat on a bounded horizon that requires accepted progression beyond the event but does not include the later 102.4 d numerical tail.

Question:

do all four unchanged controls complete 60.0 d and expose exact accepted `10:16 -> 11:16`?

## Frozen fixtures

Use exactly:

- O05 HEAD, dt = 1.25e-4 d;
- O05 HEAD, dt = 6.25e-5 d;
- O05 RUNOFF, dt = 1.25e-4 d;
- O05 RUNOFF, dt = 6.25e-5 d.

Unchanged:

- dry forcing;
- zero bottom flux;
- solver tolerances/work limits;
- persistent-KLAG control;
- event-only accepted-state logging;
- physical mass authority.

## Frozen horizon

Fixed:

`60.0 d`.

No stage extension.

## Event definition

Require exact accepted transition:

`10:16 -> 11:16`

with both states contiguous accepted saturated tails from exact paired indicators:

- `h >= 0`;
- `theta == theta_s`.

No threshold fitting, interpolation, extrapolation or split timing.

## Hard gates

Per fixture require:

- complete 60.0 d trajectory;
- finite accepted state;
- exact event exposure;
- no reverse after established late phase;
- no skipped node;
- contiguous saturation geometry;
- interval and cumulative mass within existing control gates.

## Frozen classifications

If all four fixtures qualify:

`QUALIFIED_CONFIRMATORY_RETREAT_10_TO_11_CONTROL`.

If all complete but event is absent:

`NLGLOB14Z9A_EVENT_NOT_REACHED_BY_60D`.

If otherwise-valid route/dt outcomes differ:

`NLGLOB14Z9A_MIXED_CONFIRMATORY_EXPOSURE`.

Any state geometry inconsistency:

`NLGLOB14Z9A_STATE_INCONSISTENT`.

Any process or mass failure:

`BLOCKED_NLGLOB14Z9A_CONFIRMATION`.

## Consequence

A positive result authorizes a separately preregistered split-ownership successor through:

`10:16 -> 11:16`

with ownership:

`face 9/10 -> face 10/11`.

It does not qualify later retreats, disappearance or whole-column TG re-entry.

## Production boundary

Research only. No production source/default change.
