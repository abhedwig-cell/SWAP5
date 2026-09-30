# F-PE-NLGLOB14Z13 result — split ownership through 11:16 -> 12:16

Date: 2026-09-30

Status:

`QUALIFIED_SPLIT_RETREAT_11_TO_12_OWNERSHIP_TRANSITION`

Qualification authority:

- workflow run: `36677965964`;
- segment B jobs:
  - HEAD dt=1.25e-4: `109769708254`;
  - RUNOFF dt=1.25e-4: `109769708356`;
  - HEAD dt=6.25e-5: `109769708138`;
  - RUNOFF dt=6.25e-5: `109769708224`.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Can the qualified split accepted-state trajectory independently follow:

`11:16 -> 12:16`

and move temporal ownership only from its own accepted state:

`face 10/11 -> face 11/12`?

## Coverage

PASS.

All four preregistered O05 split fixtures complete the full 140.0 d scientific horizon via exact 70.0 d checkpoint transport.

Aggregate classification:

`QUALIFIED_SPLIT_RETREAT_11_TO_12_OWNERSHIP_TRANSITION`.

## Checkpoint continuity

All four segment-A checkpoints are valid and exact.

For every fixture:

- h roundtrip is exact;
- theta roundtrip is exact;
- checkpoint accepted saturated tail is exactly `11:16`;
- temporal ownership is restored unchanged;
- segment B starts from the exact accepted segment-A endpoint;
- no synthetic event is inserted at the checkpoint.

## Accepted ownership transition

All four split trajectories independently accept:

`11:16 -> 12:16`.

Ownership moves exactly:

`face 10/11 -> face 11/12`.

No control event time is used as trigger.

## Event timing

Coarse dt = 1.25e-4 d:

- HEAD split: 123.58825 d; control: 123.58775 d; difference +0.00050 d.
- RUNOFF split: 123.585125 d; control: 123.58450 d; difference +0.000625 d.

Fine dt = 6.25e-5 d:

- HEAD split: 123.578125 d; control: 123.587875 d; difference -0.00975 d.
- RUNOFF split: 123.57500 d; control: 123.5846875 d; difference -0.0096875 d.

These timing differences are diagnostic only.

The scientific ownership authority is the exact accepted state-derived transition.

The larger fine-dt timing offset is therefore recorded as a characterization result, not used to move or fit the interface.

## Long-trajectory evidence

All four final accepted saturated tails at 140.0 d are:

`12:16`.

Each trajectory has:

- 8 total interface changes through the complete accepted sequence;
- 0 rejected intervals;
- 0 chatter;
- 0 reverse transitions;
- 0 skipped faces;
- provider-faithful dry `surface-flux` top semantics;
- rollback difference 0.

Accepted interval counts:

- HEAD coarse: 1,119,823;
- RUNOFF coarse: 1,119,789;
- HEAD fine: 2,239,650;
- RUNOFF fine: 2,239,581.

## Conservation and nonlinear gates

Observed maxima across all four fixtures:

- interval physical mass ledger: about `1.62e-9 cm`;
- nonlinear residual: about `1.00e-10` while remaining within the frozen `<=1e-10` gate;
- rollback difference: 0.

No residual redistribution, fitted interface state, duplicated interface exchange or lower-block freezing is used.

## Scientific interpretation

The moving-interface split mechanism remains stable through accepted tail `12:16`, more than 123 simulated days after the original release sequence.

State-derived temporal ownership has now moved sequentially through:

`3/4 -> 4/5 -> 5/6 -> 6/7 -> 7/8 -> 8/9 -> 9/10 -> 10/11 -> 11/12`.

This sequence is accepted-state driven and remains free of chatter, face skipping, rollback leakage and physical mass loss.

## Qualified claim boundary

Qualified:

`QUALIFIED_SPLIT_RETREAT_11_TO_12_OWNERSHIP_TRANSITION`.

Not yet qualified:

- retreats beyond `12:16`;
- complete saturated-block disappearance;
- empty-tail transition;
- whole-column TG re-entry;
- production temporal ownership.

## Consequence

Return to independent persistent-KLAG control and expose the next accepted retreat beyond `12:16`.

Only after that physical control event is independently qualified may split ownership be extended again.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
