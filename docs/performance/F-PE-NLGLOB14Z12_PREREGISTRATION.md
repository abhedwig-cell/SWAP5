# F-PE-NLGLOB14Z12 preregistration — control exposure beyond 11:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authority:

- NLGLOB14Z10: `QUALIFIED_CONFIRMATORY_RETREAT_10_TO_11_CONTROL`;
- NLGLOB14Z11: `QUALIFIED_SPLIT_RETREAT_10_TO_11_OWNERSHIP_TRANSITION`;
- all four controls confirm accepted `10:16 -> 11:16` near 53.99 d;
- split ownership independently reaches accepted `11:16`;
- complete disappearance remains unexposed.

Known numerical boundary:

- NLGLOB14Z9 fine RUNOFF later encountered an `ENDPOINT_SOLVE_FAILURE` after accepting the 10:16 -> 11:16 event and before 102.4 d;
- Z12 does not hide, repair or tune that failure;
- if it reappears before the next event, classify the control exposure accordingly.

## Purpose

Expose the next accepted physical lower-edge retreat beyond `11:16` under unchanged control numerics.

This workunit is independent persistent-KLAG control only.

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

- stage 1: 120.0 d;
- if all four fixtures do not expose the exact next retreat and remain valid: stage 2 = 240.0 d.

Do not extend beyond 240.0 d in this workunit.

## Physical event definition

The next retreat exists only when accepted saturation geometry changes exactly:

`11:16 -> 12:16`.

Both pre/post states must be contiguous accepted saturated tails defined only by:

- `h >= 0`;
- `theta == theta_s`.

No predictor crossing, fitted threshold, interpolation, extrapolation or split timing defines the event.

## Instrumentation

Use event-only accepted-state logging.

Instrumentation may reduce diagnostic volume only. It must not alter solver path, accepted state, timestep, forcing, provider semantics or mass accounting.

## Frozen classifications

If all four fixtures expose exact accepted `11:16 -> 12:16` and remain valid through the selected horizon:

`QUALIFIED_DEEPER_RETREAT_CONTROL_EXPOSURE`.

If all remain valid but no fixture reaches the event by 240.0 d:

`NLGLOB14Z12_NO_DEEPER_RETREAT_WITHIN_240D`.

If otherwise-valid event coverage differs:

`NLGLOB14Z12_MIXED_DEEPER_RETREAT_EXPOSURE`.

Any reverse/skipped/noncontiguous accepted geometry:

`NLGLOB14Z12_DEEPER_RETREAT_STATE_INCONSISTENT`.

Any process or mass failure before event exposure:

`BLOCKED_NLGLOB14Z12_CONTROL_EXPOSURE`.

If an accepted event is exposed but a fixture fails only later before the frozen selected horizon:

`BLOCKED_NLGLOB14Z12_POST_EVENT_COMPLETION`.

## Consequence

A positive result authorizes a separately preregistered split-ownership test through `11:16 -> 12:16`.

A post-event completion blocker preserves accepted event evidence but does not itself authorize split ownership; it requires a bounded confirmatory event-horizon successor, following the Z9 -> Z10 pattern.

## Production boundary

Research only. No production source/default change.
