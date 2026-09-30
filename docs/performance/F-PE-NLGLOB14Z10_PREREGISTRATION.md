# F-PE-NLGLOB14Z10 preregistration — confirm accepted retreat 10:16 -> 11:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent authority:

- NLGLOB14Z9 is `BLOCKED_NLGLOB14Z9_CONTROL_EXPOSURE` on its full 102.4 d completion contract;
- nevertheless all four Z9 controls independently accept exact physical retreat `10:16 -> 11:16` near 53.991-53.995 d;
- the Z9 blocker occurs later, after event acceptance, in fine RUNOFF.

## Purpose

Confirm the already exposed accepted physical retreat in a bounded horizon that requires progression beyond the event but excludes the later 102.4 d tail failure.

## Frozen fixtures

Use the same four O05 persistent-KLAG controls:

- HEAD, dt = 1.25e-4 d;
- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 1.25e-4 d;
- RUNOFF, dt = 6.25e-5 d;
- fixed horizon = 60.0 d;
- unchanged forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- same exact accepted-state event definition.

## Event definition

Require exact accepted transition:

`10:16 -> 11:16`

with contiguous saturated tails defined only by:

- `h >= 0`;
- `theta == theta_s`.

No predictor-only crossing, fitted threshold, interpolation, extrapolation or split timing.

## Hard gates

Per fixture require:

- complete 60.0 d trajectory;
- exact accepted event exposure;
- finite state;
- no reverse/skipped/noncontiguous geometry;
- interval mass ledger <= 5e-8 cm;
- cumulative accepted mass valid;
- unchanged provider semantics.

## Frozen classification

If all four fixtures complete 60.0 d and expose the exact accepted retreat:

`QUALIFIED_CONFIRMATORY_RETREAT_10_TO_11_CONTROL`.

If event is reached but any fixture does not complete 60.0 d:

`BLOCKED_NLGLOB14Z10_POST_EVENT_COMPLETION`.

If event is not reached in all four valid fixtures:

`NLGLOB14Z10_EVENT_NOT_CONFIRMED`.

Any geometry inconsistency:

`NLGLOB14Z10_EVENT_STATE_INCONSISTENT`.

Any process/mass failure before event exposure:

`BLOCKED_NLGLOB14Z10_CONFIRMATION`.

## Consequence

A positive result authorizes a separately preregistered split ownership test through:

`10:16 -> 11:16`

with ownership:

`face 9/10 -> face 10/11`.

It does not authorize later retreats, disappearance or whole-column TG re-entry.

## Production boundary

Research only. No production source/default change.
