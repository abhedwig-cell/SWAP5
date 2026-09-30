# F-PE-NLGLOB14Z9B preregistration — split ownership through confirmed 10:16 -> 11:16 retreat

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authority:

- NLGLOB14Z9 remains blocked under its historical 102.4 d aggregate contract;
- NLGLOB14Z9A: `QUALIFIED_CONFIRMATORY_RETREAT_10_TO_11_CONTROL`;
- all four unchanged controls complete 60.0 d and expose accepted `10:16 -> 11:16` near 53.99 d;
- NLGLOB14Z8 split ownership reaches accepted `10:16`.

## Purpose

Extend the qualified split accepted-state trajectory through the independently confirmed physical retreat:

`10:16 -> 11:16`

and move temporal ownership only from the split trajectory's own accepted state:

`face 9/10 -> face 10/11`.

## Frozen fixtures

Use O05:

- HEAD and RUNOFF;
- dt = 1.25e-4 d and 6.25e-5 d;
- total scientific horizon = 60.0 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged qualified split-domain formulation;
- provider-faithful dynamic top;
- Z9A control event time as comparator only.

## Frozen execution partition

To avoid known hosted-runner shutdowns for long monolithic split jobs, execute every unchanged scientific fixture in five fixed sequential segments:

- 0 -> 12 d;
- 12 -> 24 d;
- 24 -> 36 d;
- 36 -> 48 d;
- 48 -> 60 d.

The partition is fixed before result exposure and is identical in scientific meaning to one continuous 60 d accepted-state trajectory.

At each segment boundary serialize and restore exactly:

- pressure-head vector;
- water-content vector;
- accepted saturated tail / temporal ownership;
- event history;
- accepted interval counters;
- max mass/residual/rollback diagnostics accumulated so far.

## Checkpoint continuity gates

At every boundary require:

- bit-exact h roundtrip;
- bit-exact theta roundtrip;
- resumed accepted tail equals previous final tail;
- resumed ownership equals previous final ownership;
- no synthetic transition at restart;
- first resumed interval starts from the exact accepted prior endpoint.

Any continuity failure invalidates the execution; it is not a physical failure classification.

## Ownership authority

At every accepted split state derive lower saturation only from exact paired physical indicators.

Ownership may move only after exact accepted split transition:

`10:16 -> 11:16`.

No control event time, fitted threshold, predictor crossing or hysteresis may trigger the move.

## Hard gates

Per fixture require jointly across all five segments:

- complete 60.0 d trajectory;
- finite accepted state;
- residual <= 1e-10;
- accepted-interval physical mass ledger <= 5e-8 cm;
- exact rollback;
- contiguous lower saturated tail;
- exact one-face move `9/10 -> 10/11`;
- no chatter/reverse;
- no skipped face;
- provider-faithful dry top;
- exact checkpoint continuity.

## Frozen classifications

If all four fixtures qualify:

`QUALIFIED_SPLIT_RETREAT_10_TO_11_OWNERSHIP_TRANSITION`.

If all complete but the event is not reached:

`NLGLOB14Z9B_SPLIT_RETREAT_NOT_REACHED_BY_60D`.

Any checkpoint continuity failure:

`NLGLOB14Z9B_CHECKPOINT_CONTINUITY_INVALID`.

Any chatter/reverse:

`NLGLOB14Z9B_INTERFACE_CHATTER`.

Any skipped/noncontiguous geometry:

`NLGLOB14Z9B_GEOMETRY_INCONSISTENT`.

Any coupling failure with clean rollback:

`NLGLOB14Z9B_COUPLING_NOT_CLOSED`.

Any mass/transaction leak:

`NLGLOB14Z9B_TRANSACTION_INCONSISTENT`.

## Consequence

Positive Z9B qualifies state-driven split ownership through accepted saturated tail `11:16`.

It does not qualify later retreats, complete disappearance, whole-column TG re-entry or production temporal ownership.

## Production boundary

Research only. No production source/default change.
