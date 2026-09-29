# F-PE-NLGLOB14Z5 preregistration — split ownership through 7:16 -> 8:16

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authority:

- NLGLOB14Y: `QUALIFIED_SPLIT_MULTI_RETREAT_OWNERSHIP_SEQUENCE`, split accepted state reaches `7:16` by 0.80 d;
- NLGLOB14Z3: repaired finest control confirms accepted physical `7:16 -> 8:16` near 2.44 d;
- NLGLOB14Z4: control later exposes `8:16 -> 9:16` near 7.65 d;
- split ownership has not yet independently crossed `7:16 -> 8:16`.

## Purpose

Extend the qualified split accepted-state trajectory through the independently exposed physical retreat:

`7:16 -> 8:16`

and move temporal ownership only from its own accepted state:

`face 6/7 -> face 7/8`.

## Frozen fixtures

Use O05:

- HEAD and RUNOFF;
- dt = 1.25e-4 d and 6.25e-5 d;
- fixed horizon = 2.80 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- same qualified split-domain formulation as NLGLOB14Y;
- same provider-faithful dynamic top.

Persistent-KLAG control on the same fixture is comparator only.

## Ownership rule

At each accepted split state derive the contiguous lower saturated tail exactly from:

- `h >= 0`;
- `theta == theta_s`.

Ownership changes only after the split trajectory itself changes accepted tail:

`7:16 -> 8:16`.

No control event time, pressure threshold, theta epsilon, hysteresis or predictor-only crossing may trigger the move.

## Hard gates

Require per fixture:

- complete 2.80 d trajectory;
- finite accepted state;
- residual <= 1e-10;
- interval mass ledger <= 5e-8 cm;
- exact rollback of rejected candidates;
- contiguous lower saturated geometry;
- exact one-face move `6/7 -> 7/8`;
- no reverse/chatter;
- no skipped face;
- provider-faithful dry top.

## Frozen classifications

If all four fixtures cross the exact accepted retreat and ownership move cleanly:

`QUALIFIED_SPLIT_LATE_RETREAT_OWNERSHIP_TRANSITION`.

If valid trajectories complete but do not reach the retreat:

`NLGLOB14Z5_SPLIT_LATE_RETREAT_NOT_REACHED`.

Any chatter/reverse:

`NLGLOB14Z5_LATE_INTERFACE_CHATTER`.

Any skipped/noncontiguous geometry:

`NLGLOB14Z5_LATE_GEOMETRY_INCONSISTENT`.

Any coupling failure with clean rollback:

`NLGLOB14Z5_LATE_COUPLING_NOT_CLOSED`.

Any mass/transaction leak:

`NLGLOB14Z5_LATE_TRANSACTION_INCONSISTENT`.

## Consequence

Positive Z5 authorizes the next split continuation from `8:16` toward the independently exposed `8:16 -> 9:16` event.

It does not qualify disappearance or whole-column TG re-entry.

## Production boundary

Research only. No production source/default change.
