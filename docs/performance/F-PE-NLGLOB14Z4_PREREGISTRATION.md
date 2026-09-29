# F-PE-NLGLOB14Z4 preregistration — later-retreat control exposure beyond 8:16

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent authority:

- NLGLOB14Z3: `QUALIFIED_REPAIRED_FINEST_LATE_RETREAT_TRAJECTORY`;
- accepted control retreat `7:16 -> 8:16` is qualified near 2.44 d;
- finest-dt local retry is transaction-safe and recoverable by exactly `dt/2 + dt/2`;
- complete saturated-block disappearance remains unexposed.

## Purpose

Expose the next accepted physical retreat beyond `8:16` without extrapolation.

This workunit is control-only and does not test split ownership.

## Frozen fixtures

Use O05 persistent saturated-KLAG control:

- HEAD and RUNOFF;
- dt = 1.25e-4 d and 6.25e-5 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- physical mass as authority.

These two levels are already complete and stable through 6.4 d without retry repair.

## Frozen staged horizons

Run:

- stage 1: 12.8 d;
- if neither route/dt family exposes retreat beyond `8:16`, stage 2: 25.6 d.

Do not extend beyond 25.6 d in this workunit.

## Physical event definition

The next retreat is accepted only when the saturated set changes exactly:

`8:16 -> 9:16`.

Both states must be contiguous accepted saturated tails defined by:

- `h >= 0`;
- `theta == theta_s`.

No predictor state, fitted threshold, interpolation or extrapolation defines the event.

## Instrumentation constraint

To keep the long-horizon control tractable, event logging may be reduced to accepted saturated-tail changes only.

Instrumentation may not alter:

- accepted state;
- solver path;
- forcing;
- timestep;
- mass accounting;
- provider semantics.

## Frozen classifications

If all four fixtures expose exact accepted `8:16 -> 9:16` with valid mass/geometry:

`QUALIFIED_NEXT_LATE_RETREAT_CONTROL_EXPOSURE`.

If all remain valid but no fixture reaches the event by 25.6 d:

`NLGLOB14Z4_NO_NEXT_RETREAT_WITHIN_25P6D`.

If route/dt outcomes differ while remaining valid:

`NLGLOB14Z4_MIXED_NEXT_RETREAT_EXPOSURE`.

Any reverse/skipped/noncontiguous state:

`NLGLOB14Z4_LATE_RETREAT_STATE_INCONSISTENT`.

Any process/mass failure:

`BLOCKED_NLGLOB14Z4_CONTROL_EXPOSURE`.

## Consequence

A positive result authorizes a separately preregistered split-ownership transition test through `8:16 -> 9:16`.

It does not qualify disappearance or whole-column TG re-entry.

## Production boundary

Research only. No production source/default change.
