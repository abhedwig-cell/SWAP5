# F-PE-NLGLOB14Z16 result — event-terminated split confirmation 12:16 -> 13:16

Date: 2026-09-30

Status:

`QUALIFIED_EVENT_TERMINATED_SPLIT_RETREAT_12_TO_13`

Qualification authority:

- workflow run: `36685741765`;
- segment A/B jobs:
  - HEAD dt=1.25e-4: `109791068426` / `109796066877`;
  - RUNOFF dt=1.25e-4: `109791068878` / `109796066898`;
  - HEAD dt=6.25e-5: `109791068979` / `109796066872`;
  - RUNOFF dt=6.25e-5: `109791068797` / `109796066722`.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Can all four split trajectories qualify the target ownership transition itself by terminating immediately after the first exact accepted:

`12:16 -> 13:16`

with ownership:

`face 11/12 -> face 12/13`

without requiring unrelated post-event continuation?

## Coverage

PASS.

All four preregistered fixtures reach and accept the exact target event before the 262 d execution cap.

Aggregate classification:

`QUALIFIED_EVENT_TERMINATED_SPLIT_RETREAT_12_TO_13`.

## Checkpoint continuity

All four 140.0 d checkpoints are exact.

For every fixture:

- h roundtrip is bit-exact;
- theta roundtrip is bit-exact;
- checkpoint saturated tail is exactly `12:16`;
- temporal ownership is restored unchanged;
- segment B begins from the accepted segment-A endpoint;
- no synthetic event is inserted at restart.

## Accepted event endpoint

All four split trajectories independently accept:

`12:16 -> 13:16`.

Ownership moves exactly:

`face 11/12 -> face 12/13`.

No interval after the accepted target event is attempted.

## Event timing

HEAD:

- dt 1.25e-4 d:
  - split: 260.947000 d;
  - control comparator: 260.961125 d.
- dt 6.25e-5 d:
  - split: 260.933500 d;
  - control comparator: 260.9613125 d.

RUNOFF:

- dt 1.25e-4 d:
  - split: 260.944000 d;
  - control comparator: 260.957875 d.
- dt 6.25e-5 d:
  - split: 260.9303125 d;
  - control comparator: 260.958125 d.

These timing offsets are diagnostic only.

Accepted split state remains the sole ownership authority.

## State and ownership quality

Across all four target-event endpoints:

- rejected intervals: 0;
- chatter: 0;
- reverse transitions: 0;
- skipped faces: 0;
- final accepted saturated tail: `13:16`;
- interface-change count: 8 per trajectory;
- provider-faithful dry `surface-flux` top semantics;
- rollback difference: 0.

## Conservation and nonlinear gates

Observed maxima:

- interval physical mass ledger: about `1.62e-9 cm`;
- nonlinear residual: about `1.00e-10`;
- rollback difference: 0.

All remain within the frozen scientific gates.

## Scientific interpretation

The Z15 post-event fine-dt `UPPER` failure is not part of the target ownership transition itself.

When the workunit endpoint is defined as the accepted physical event, all four fixtures qualify the same state-derived ownership move cleanly.

This establishes split ownership through accepted tail `13:16` without repairing or bypassing the Z15 post-event boundary.

## Qualified claim boundary

Qualified:

`QUALIFIED_EVENT_TERMINATED_SPLIT_RETREAT_12_TO_13`.

Not qualified:

- persistence of fine-dt split evolution after accepted `13:16`;
- repair of the Z15 post-event `UPPER` boundary;
- retreats beyond `13:16`;
- complete saturated-block disappearance;
- empty-tail transition;
- whole-column TG re-entry;
- production temporal ownership.

## Consequence

The next safe step returns to independent persistent-KLAG control exposure beyond accepted tail `13:16`.

Only after the next physical control retreat is independently established may split ownership be extended again.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
