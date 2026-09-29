# F-PE-NLGLOB14Z8 preregistration — split ownership through 9:16 -> 10:16

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authority:

- NLGLOB14Z6: `QUALIFIED_SPLIT_NEXT_LATE_RETREAT_OWNERSHIP_TRANSITION`, split accepted state reaches `9:16`;
- NLGLOB14Z7: `QUALIFIED_CONFIRMATORY_RETREAT_9_TO_10_CONTROL`, control confirms `9:16 -> 10:16` near 21.455 d.

## Purpose

Extend the qualified split accepted-state trajectory through the independently exposed physical retreat:

`9:16 -> 10:16`

and move temporal ownership only from its own accepted state:

`face 8/9 -> face 9/10`.

## Frozen fixtures

Use O05:

- HEAD and RUNOFF;
- dt = 1.25e-4 d and 6.25e-5 d;
- horizon = 25.60 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged split-domain formulation;
- provider-faithful dynamic top;
- persistent-KLAG control only as comparator.

## Ownership authority

At every accepted split state derive the lower saturated tail exactly from accepted physical state.

Ownership may move only after exact accepted transition:

`9:16 -> 10:16`.

No control event time or fitted threshold may trigger ownership.

## Hard gates

Per fixture require:

- complete 25.60 d trajectory;
- finite accepted state;
- residual <= 1e-10;
- interval mass ledger <= 5e-8 cm;
- exact rollback;
- contiguous saturated tail;
- exact one-face move `8/9 -> 9/10`;
- no chatter/reverse;
- no skipped face;
- provider-faithful dry top.

## Frozen classifications

If all four fixtures qualify:

`QUALIFIED_SPLIT_FURTHER_LATE_RETREAT_OWNERSHIP_TRANSITION`.

Valid but event not reached:

`NLGLOB14Z8_SPLIT_FURTHER_RETREAT_NOT_REACHED`.

Chatter/reverse:

`NLGLOB14Z8_FURTHER_LATE_INTERFACE_CHATTER`.

Skipped/noncontiguous geometry:

`NLGLOB14Z8_FURTHER_LATE_GEOMETRY_INCONSISTENT`.

Coupling failure with clean rollback:

`NLGLOB14Z8_FURTHER_LATE_COUPLING_NOT_CLOSED`.

Mass/transaction leak:

`NLGLOB14Z8_FURTHER_LATE_TRANSACTION_INCONSISTENT`.

## Consequence

Positive Z8 qualifies state-driven split ownership through accepted saturated tail `10:16`.

Complete disappearance and whole-column TG re-entry remain unqualified.

## Production boundary

Research only. No production source/default change.
