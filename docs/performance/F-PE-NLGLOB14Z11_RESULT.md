# F-PE-NLGLOB14Z11 result — split ownership through 10:16 -> 11:16

Date: 2026-09-30

Status:

`QUALIFIED_SPLIT_RETREAT_10_TO_11_OWNERSHIP_TRANSITION`

Qualification authority:

- workflow run: `36671939031`;
- segment A/B jobs:
  - HEAD dt=1.25e-4: `109748616894` / `109749864886`;
  - RUNOFF dt=1.25e-4: `109748616724` / `109749864778`;
  - HEAD dt=6.25e-5: `109748616992` / `109749864805`;
  - RUNOFF dt=6.25e-5: `109748617244` / `109749864813`.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Can the qualified split accepted-state trajectory independently follow accepted physical retreat:

`10:16 -> 11:16`

and move temporal ownership only from its own accepted state:

`face 9/10 -> face 10/11`?

## Coverage

PASS.

All four O05 fixtures complete the full 60.0 d scientific horizon via the preregistered exact 30.0 d checkpoint partition.

Aggregate classification:

`QUALIFIED_SPLIT_RETREAT_10_TO_11_OWNERSHIP_TRANSITION`.

## Checkpoint continuity

All four segment-A checkpoints at 30.0 d are valid.

For every fixture:

- h roundtrip is exact;
- theta roundtrip is exact;
- checkpoint tail is exactly `10:16`;
- temporal ownership is restored unchanged;
- segment B starts from the exact accepted segment-A endpoint;
- no synthetic event is inserted at the checkpoint.

## Accepted ownership transition

All four split trajectories independently accept:

`10:16 -> 11:16`.

Ownership moves exactly:

`face 9/10 -> face 10/11`.

No control event time is used as a trigger.

## Event timing

Coarse dt = 1.25e-4 d:

- HEAD split: 53.994875 d; control: 53.994375 d.
- RUNOFF split: 53.991750 d; control: 53.991250 d.

Fine dt = 6.25e-5 d:

- HEAD split: 53.992875 d; control: 53.994500 d.
- RUNOFF split: 53.9895625 d; control: 53.9913125 d.

These timing differences are diagnostic only. The scientific authority is the accepted state-derived transition.

## Long-trajectory evidence

Final accepted saturated tail at 60.0 d is `11:16` for all four fixtures.

Every trajectory shows:

- 7 total interface changes through the full sequence;
- 0 rejected intervals;
- 0 chatter;
- 0 reverse transitions;
- 0 skipped faces;
- provider-faithful dry `surface-flux` top semantics.

## Conservation and nonlinear gates

Observed maxima across all four fixtures:

- interval physical mass ledger: about `1.62e-9 cm`;
- nonlinear residual: about `1.00e-10`;
- rollback difference: 0.

All remain within the frozen gates.

## Scientific interpretation

The moving-interface split mechanism remains stable through accepted tail `11:16`, more than 53 simulated days after the original release sequence.

State-derived temporal ownership has now moved sequentially through:

`3/4 -> 4/5 -> 5/6 -> 6/7 -> 7/8 -> 8/9 -> 9/10 -> 10/11`

without chatter, skip, rollback leakage or mass loss.

## Qualified claim boundary

Qualified:

`QUALIFIED_SPLIT_RETREAT_10_TO_11_OWNERSHIP_TRANSITION`.

Not yet qualified:

- retreats beyond `11:16`;
- complete saturated-block disappearance;
- empty-tail transition;
- whole-column TG re-entry;
- production temporal ownership.

## Consequence

Return to independent persistent-KLAG control and expose the next accepted retreat beyond `11:16`.

Only after that control event is independently qualified may split ownership be extended again.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
