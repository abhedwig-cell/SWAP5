# F-PE-NLGLOB14Z6 result — split ownership through 8:16 -> 9:16

Date: 2026-09-29

Status:

`QUALIFIED_SPLIT_NEXT_LATE_RETREAT_OWNERSHIP_TRANSITION`

Qualification authority:

- workflow run: `36631538898`;
- job: `109621718099`;
- conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Can the qualified split accepted-state trajectory independently follow the physical retreat:

`8:16 -> 9:16`

and move temporal ownership only from its own accepted state:

`face 7/8 -> face 8/9`?

## Coverage

PASS.

All four frozen O05 fixtures qualify:

- HEAD, dt = 1.25e-4 d;
- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 1.25e-4 d;
- RUNOFF, dt = 6.25e-5 d.

All complete the full 12.80 d horizon.

Aggregate classification:

`QUALIFIED_SPLIT_NEXT_LATE_RETREAT_OWNERSHIP_TRANSITION`.

## Accepted ownership sequence

Every split trajectory independently reaches:

`4:16 -> 5:16 -> 6:16 -> 7:16 -> 8:16 -> 9:16`.

Temporal ownership follows:

`3/4 -> 4/5 -> 5/6 -> 6/7 -> 7/8 -> 8/9`.

No control event time is used as a switch trigger.

## Next late retreat

HEAD:

- dt 1.25e-4 d:
  - control: 7.65275 d;
  - split: 7.653125 d;
  - difference: +3 dt.
- dt 6.25e-5 d:
  - control: 7.65275 d;
  - split: 7.6529375 d;
  - difference: +3 dt.

RUNOFF:

- dt 1.25e-4 d:
  - control: 7.649625 d;
  - split: 7.649875 d;
  - difference: +2 dt.
- dt 6.25e-5 d:
  - control: 7.649625 d;
  - split: 7.64975 d;
  - difference: +2 dt.

Event-time comparison is diagnostic only. State-derived accepted ownership remains the authority.

## Long-trajectory evidence

Across the four fixtures:

- accepted split intervals: 613,243;
- process failures: 0;
- rejected intervals: 0;
- interface changes: 20 total;
- chatter: 0;
- reverse cases: 0;
- skipped nodes/faces: 0.

All final accepted saturated sets at 12.80 d are nodes 9:16.

## Conservation and transactions

Observed maxima:

- absolute interval physical mass ledger: about `6.37e-10 cm`;
- node residual: about `6.43e-11`;
- rollback difference: 0.

No residual redistribution, fitted interface head, duplicated interface exchange or lower-block freezing is used.

## Dynamic-top behavior

All accepted split intervals retain provider-faithful dry `surface-flux` semantics.

Control top fluxes are not replayed into the split solve.

## Scientific interpretation

The moving-interface mechanism remains stable through an additional late retreat more than seven simulated days after the original handoff.

The split trajectory has now independently carried temporal ownership from face 3/4 through face 8/9 with no chatter, skipping, rollback leakage or mass loss.

## Qualified claim boundary

Qualified:

`QUALIFIED_SPLIT_NEXT_LATE_RETREAT_OWNERSHIP_TRANSITION`.

Not yet qualified:

- physical retreats beyond 9:16;
- complete saturated-block disappearance;
- whole-column TG re-entry;
- production temporal ownership.

## Consequence

Open an independent control-exposure successor for the next retreat beyond `9:16`, preserving current forcing and qualified transaction policy. Only after control exposure may split ownership be extended further.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
