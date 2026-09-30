# F-PE-NLGLOB14Z17 preregistration — control exposure beyond 13:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authority:

- NLGLOB14Z14/Z14C restore four-fixture control authority for accepted physical retreat `12:16 -> 13:16`;
- NLGLOB14Z16: `QUALIFIED_EVENT_TERMINATED_SPLIT_RETREAT_12_TO_13`;
- split ownership independently reaches accepted tail `13:16`;
- complete saturated-block disappearance remains unexposed.

Known numerical boundary:

- long dry-horizon controls can encounter isolated `SW_SOLVE_RETRY_ADVISED` intervals;
- Z17 does not preemptively repair or tune them;
- any failure before target event is classified and attributed in a separate successor.

## Purpose

Expose the next accepted physical lower-edge retreat beyond `13:16` under unchanged persistent-KLAG control numerics.

This workunit is control only.

## Frozen fixtures

Use O05:

- HEAD and RUNOFF;
- dt = 1.25e-4 d and 6.25e-5 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- physical mass as hard authority.

## Frozen staged horizons

Run:

- stage 1: 600.0 d;
- if all four fixtures remain valid but the target event is not exposed: stage 2 = 1200.0 d.

Do not extend beyond 1200.0 d in this workunit.

The horizon does not define event timing.

## Physical event definition

The target event exists only when accepted saturation geometry changes exactly:

`13:16 -> 14:16`.

Both pre/post states must be contiguous accepted saturated tails defined only by:

- `h >= 0`;
- `theta == theta_s`.

No predictor crossing, fitted threshold, interpolation, extrapolation, split timing or count-only heuristic defines the event.

## Instrumentation

Use event-only accepted-state logging.

Instrumentation may reduce diagnostic volume only. It must not alter solver path, timestep, forcing, provider semantics, accepted state or mass accounting.

## Frozen classifications

If all four fixtures expose exact accepted `13:16 -> 14:16` and remain valid through the selected horizon:

`QUALIFIED_RETREAT_13_TO_14_CONTROL_EXPOSURE`.

If all remain valid but no fixture reaches the event by 1200 d:

`NLGLOB14Z17_NO_RETREAT_13_TO_14_WITHIN_1200D`.

If otherwise-valid event coverage differs:

`NLGLOB14Z17_MIXED_RETREAT_13_TO_14_EXPOSURE`.

Any reverse/skipped/noncontiguous accepted geometry:

`NLGLOB14Z17_RETREAT_STATE_INCONSISTENT`.

Any process or mass failure before event exposure:

`BLOCKED_NLGLOB14Z17_CONTROL_EXPOSURE`.

If an accepted event is exposed but a fixture fails only later before the selected horizon:

`BLOCKED_NLGLOB14Z17_POST_EVENT_COMPLETION`.

## Consequence

A positive result authorizes a separately preregistered split-ownership test through:

`13:16 -> 14:16`

with ownership:

`face 12/13 -> face 13/14`.

A retry-advised blocker requires separate bounded attribution/recovery before split authorization.

## Production boundary

Research only. No production source/default change.
