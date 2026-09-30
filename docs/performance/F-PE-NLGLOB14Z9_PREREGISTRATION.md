# F-PE-NLGLOB14Z9 preregistration — control exposure beyond 10:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authority:

- NLGLOB14Z7: independent control exposes accepted `9:16 -> 10:16` near 21.455 d;
- NLGLOB14Z8: split ownership independently follows that event and reaches accepted `10:16`;
- complete saturated-block disappearance remains unexposed.

## Purpose

Expose the next accepted physical lower-edge retreat beyond `10:16` under unchanged forcing.

This workunit is independent persistent-KLAG control only.

## Frozen fixtures

Use O05:

- HEAD and RUNOFF;
- dt = 1.25e-4 d and 6.25e-5 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- physical mass as authority.

## Frozen staged horizons

Run:

- stage 1: 51.2 d;
- if all four fixtures do not expose the exact next retreat: stage 2 = 102.4 d.

Do not extend beyond 102.4 d in this workunit.

## Physical event definition

The next retreat exists only when accepted saturation geometry changes exactly:

`10:16 -> 11:16`.

Both pre/post states must be contiguous accepted saturated tails defined by exact paired indicators:

- `h >= 0`;
- `theta == theta_s`.

No predictor crossing, fitted threshold, interpolation, extrapolation or split timing defines the event.

## Instrumentation

Use event-only accepted-state logging as qualified for long-horizon control exposure.

Instrumentation may reduce diagnostic volume only. It must not alter solver path, accepted state, timestep, forcing, provider semantics or mass accounting.

## Frozen classifications

If all four fixtures expose exact accepted `10:16 -> 11:16` with valid state/mass:

`QUALIFIED_DEEP_LATE_RETREAT_CONTROL_EXPOSURE`.

If all remain valid but no fixture reaches the event by 102.4 d:

`NLGLOB14Z9_NO_DEEP_RETREAT_WITHIN_102P4D`.

If otherwise-valid coverage differs:

`NLGLOB14Z9_MIXED_DEEP_RETREAT_EXPOSURE`.

Any reverse/skipped/noncontiguous accepted geometry:

`NLGLOB14Z9_DEEP_RETREAT_STATE_INCONSISTENT`.

Any process or physical-mass failure:

`BLOCKED_NLGLOB14Z9_CONTROL_EXPOSURE`.

## Consequence

A positive result authorizes a separately preregistered split-ownership test through `10:16 -> 11:16`.

It does not qualify complete disappearance or whole-column TG re-entry.

## Production boundary

Research only. No production source/default change.
