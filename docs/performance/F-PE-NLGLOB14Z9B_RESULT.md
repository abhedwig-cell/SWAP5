# F-PE-NLGLOB14Z9B result — split ownership through confirmed 10:16 -> 11:16 retreat

Date: 2026-09-30

Status:

`QUALIFIED_SPLIT_RETREAT_10_TO_11_OWNERSHIP_TRANSITION`

Qualification authority:

- workflow run: `36671268109`;
- final segment jobs:
  - HEAD coarse: `109748751306`;
  - HEAD fine: `109748751424`;
  - RUNOFF coarse: `109748751236`;
  - RUNOFF fine: `109748751251`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Can the qualified split accepted-state trajectory independently follow the confirmed physical retreat:

`10:16 -> 11:16`

and move temporal ownership only from its own accepted state:

`face 9/10 -> face 10/11`?

## Execution and checkpoint authority

The 60.0 d scientific trajectory was preregistered as five fixed sequential segments:

- 0 -> 12 d;
- 12 -> 24 d;
- 24 -> 36 d;
- 36 -> 48 d;
- 48 -> 60 d.

All twenty segment jobs complete successfully.

At every checkpoint:

- h roundtrips exactly;
- theta roundtrips exactly;
- accepted saturated tail is preserved;
- temporal ownership is preserved;
- no synthetic interface event is created at restart.

Thus the segmented execution is one continuous accepted-state trajectory for scientific interpretation.

## Coverage

PASS.

All four frozen O05 fixtures classify:

`SPLIT_RETREAT_10_TO_11_TRANSITION_VALID`.

Aggregate classification:

`QUALIFIED_SPLIT_RETREAT_10_TO_11_OWNERSHIP_TRANSITION`.

## Physical and ownership transition

All four split trajectories independently reach exact accepted:

`10:16 -> 11:16`.

Ownership moves exactly:

`face 9/10 -> face 10/11`.

No control event time is used as a trigger.

### HEAD

dt = 1.25e-4 d:

- control event: 53.994375 d;
- split event: 53.994875 d;
- difference: +0.000500 d = +4 dt.

dt = 6.25e-5 d:

- control event: 53.994500 d;
- split event: 53.992875 d;
- difference: -0.001625 d.

### RUNOFF

dt = 1.25e-4 d:

- control event: 53.991250 d;
- split event: 53.991750 d;
- difference: +0.000500 d = +4 dt.

dt = 6.25e-5 d:

- control event: 53.9913125 d;
- split event: 53.9895625 d;
- difference: -0.001750 d.

Event-time agreement is diagnostic only. The frozen qualification authority is the accepted physical state transition and ownership semantics, not event-time identity.

The fine-dt timing offset is therefore preserved as an observed research result rather than tuned away.

## Long-trajectory evidence

Across all four 60 d split trajectories:

- accepted intervals: 2,878,843;
- rejected intervals: 0;
- interface changes: 28 total;
- chatter: 0;
- reverse transitions: 0;
- skipped ownership faces: 0.

All final accepted saturated sets are:

`nodes 11:16`.

## Conservation and nonlinear gates

Observed maxima:

- accepted-interval physical mass ledger: about `1.62e-9 cm`;
- nonlinear residual: about `1.00e-10`, within the frozen gate;
- rollback difference: 0.

No residual redistribution, fitted interface head, duplicate interface authority or lower-block freezing is used.

## Dynamic-top behavior

All trajectories retain provider-faithful dry `surface-flux` semantics.

Control flux histories are not replayed into the split solve.

## Scientific interpretation

The moving-interface split mechanism now remains stable through a confirmed retreat occurring roughly 54 simulated days after the initial transition sequence.

State-derived temporal ownership has been carried through:

`3/4 -> 4/5 -> 5/6 -> 6/7 -> 7/8 -> 8/9 -> 9/10 -> 10/11`

without chatter, skipping, rejected accepted-state leakage or mass failure.

The fine-dt event timing departs somewhat from persistent-KLAG control timing while retaining the same accepted physical retreat. This is an explicit temporal-discretization difference, not a reason to replace accepted physical state as ownership authority.

## Qualified claim boundary

Qualified:

`QUALIFIED_SPLIT_RETREAT_10_TO_11_OWNERSHIP_TRANSITION`.

Not yet qualified:

- retreats beyond 11:16;
- complete saturated-block disappearance;
- empty accepted saturated tail;
- whole-column TG re-entry after disappearance;
- production temporal ownership.

## Consequence

Return to independent persistent-KLAG control and expose the next physical retreat beyond accepted tail `11:16`.

Only after independent control exposure may split ownership be extended again.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
