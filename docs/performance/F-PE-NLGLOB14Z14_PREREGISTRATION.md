# F-PE-NLGLOB14Z14 preregistration — control exposure beyond 12:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authority:

- NLGLOB14Z12/Z12C restore four-fixture research authority for accepted physical retreat `11:16 -> 12:16`;
- NLGLOB14Z13: `QUALIFIED_SPLIT_RETREAT_11_TO_12_OWNERSHIP_TRANSITION`;
- all qualified split trajectories reach accepted tail `12:16`;
- complete saturated-block disappearance remains unexposed.

Known numerical boundary:

- long dry-horizon fixed-dt control trajectories can encounter local `SW_SOLVE_RETRY_ADVISED` intervals;
- Z14 does not preemptively repair or tune such intervals;
- if a retry/failure occurs before event exposure, classify it and preserve accepted-state evidence.

## Purpose

Expose the next accepted physical lower-edge retreat beyond `12:16` under unchanged persistent-KLAG control numerics.

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

- stage 1: 300.0 d;
- if all four fixtures do not expose the exact next retreat and remain valid: stage 2 = 600.0 d.

Do not extend beyond 600.0 d in this workunit.

Horizon selection is independent of split behavior and does not define event timing.

## Physical event definition

The next retreat exists only when accepted saturation geometry changes exactly:

`12:16 -> 13:16`.

Both pre/post states must be contiguous accepted saturated tails defined only by exact paired indicators:

- `h >= 0`;
- `theta == theta_s`.

No predictor crossing, fitted pressure threshold, theta epsilon, interpolation, extrapolation or split timing defines the event.

## Instrumentation

Use event-only accepted-state logging.

Instrumentation may reduce diagnostic volume only. It must not alter solver path, accepted state, timestep, forcing, provider semantics or mass accounting.

## Frozen classifications

If all four fixtures expose exact accepted `12:16 -> 13:16` and remain valid through the selected horizon:

`QUALIFIED_RETREAT_12_TO_13_CONTROL_EXPOSURE`.

If all remain valid but no fixture reaches the event by 600.0 d:

`NLGLOB14Z14_NO_RETREAT_12_TO_13_WITHIN_600D`.

If otherwise-valid event coverage differs:

`NLGLOB14Z14_MIXED_RETREAT_12_TO_13_EXPOSURE`.

Any reverse/skipped/noncontiguous accepted geometry:

`NLGLOB14Z14_RETREAT_STATE_INCONSISTENT`.

Any process or mass failure before event exposure:

`BLOCKED_NLGLOB14Z14_CONTROL_EXPOSURE`.

If an accepted event is exposed but a fixture fails only later before the selected horizon:

`BLOCKED_NLGLOB14Z14_POST_EVENT_COMPLETION`.

## Consequence

A positive result authorizes a separately preregistered split-ownership test through:

`12:16 -> 13:16`

with ownership:

`face 11/12 -> face 12/13`.

A pre-event retry-advised blocker requires bounded local attribution/recovery before split authorization.

A post-event completion blocker preserves accepted event evidence but requires a bounded confirmatory event-horizon successor before split authorization.

## Production boundary

Research only. No production source/default change.
