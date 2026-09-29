# F-PE-NLGLOB14Z5 result — split ownership through 7:16 -> 8:16

Date: 2026-09-29

Status:

`QUALIFIED_SPLIT_LATE_RETREAT_OWNERSHIP_TRANSITION`

Qualification authority:

- workflow run: `36622130211`;
- job: `109589884191`;
- conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Can the qualified split accepted-state trajectory independently follow the physical retreat:

`7:16 -> 8:16`

and move temporal ownership only from its own accepted state:

`face 6/7 -> face 7/8`?

## Coverage

PASS.

All four frozen O05 fixtures qualify:

- HEAD, dt = 1.25e-4 d;
- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 1.25e-4 d;
- RUNOFF, dt = 6.25e-5 d.

All complete the full 2.80 d horizon.

Aggregate classification:

`QUALIFIED_SPLIT_LATE_RETREAT_OWNERSHIP_TRANSITION`.

## Accepted ownership sequence

Every split trajectory independently reaches:

`4:16 -> 5:16 -> 6:16 -> 7:16 -> 8:16`.

Temporal ownership follows:

`3/4 -> 4/5 -> 5/6 -> 6/7 -> 7/8`.

No control event time is used as a switch trigger.

## Late retreat

HEAD:

- dt 1.25e-4 d:
  - control: 2.442875 d;
  - split: 2.443125 d;
  - difference: +2 dt.
- dt 6.25e-5 d:
  - control: 2.442875 d;
  - split: 2.443000 d;
  - difference: +2 dt.

RUNOFF:

- dt 1.25e-4 d:
  - control: 2.439750 d;
  - split: 2.440000 d;
  - difference: +2 dt.
- dt 6.25e-5 d:
  - control: 2.4396875 d;
  - split: 2.439875 d;
  - difference: +3 dt.

Event-time comparison is diagnostic only. State-derived ownership remains the authority.

## Long-trajectory evidence

Across the four fixtures:

- accepted split intervals: 133,243;
- process failures: 0;
- rejected intervals: 0;
- interface changes: 16 total;
- chatter: 0;
- reverse cases: 0;
- skipped nodes/faces: 0.

All final accepted saturated sets at 2.80 d are nodes 8:16.

## Conservation and transactions

Observed maxima:

- absolute interval physical mass ledger: about `6.37e-10 cm`;
- node residual: about `6.43e-11`;
- rollback difference: 0.

No residual redistribution, fitted interface head, duplicated interface exchange or lower-block freezing is used.

## Dynamic-top behavior

All accepted split intervals retain the dry provider-faithful `surface-flux` route.

The control top-flux sequence is not replayed into the split solve.

## Scientific interpretation

The moving-interface mechanism now remains stable across one additional late physical retreat more than two simulated days after the earlier sequence.

The split trajectory has independently carried temporal ownership from face 3/4 through face 7/8 without chatter, skipping or mass loss.

This materially extends the qualified moving-interface temporal-ownership result.

## Qualified claim boundary

Qualified:

`QUALIFIED_SPLIT_LATE_RETREAT_OWNERSHIP_TRANSITION`.

Not yet qualified:

- split transition `8:16 -> 9:16`;
- complete saturated-block disappearance;
- whole-column TG re-entry after disappearance;
- production temporal ownership.

## Consequence

NLGLOB14Z4 independently exposes control retreat `8:16 -> 9:16` near 7.65 d.

A separately preregistered successor may now extend the split trajectory to that event and require ownership transition:

`face 7/8 -> face 8/9`.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
