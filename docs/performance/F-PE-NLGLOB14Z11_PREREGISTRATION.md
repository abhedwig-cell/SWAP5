# F-PE-NLGLOB14Z11 preregistration — split ownership through 10:16 -> 11:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authority:

- NLGLOB14Z10: `QUALIFIED_CONFIRMATORY_RETREAT_10_TO_11_CONTROL`;
- all four controls complete 60.0 d and confirm exact accepted `10:16 -> 11:16` near 53.991-53.995 d;
- split ownership is already qualified through accepted tail `10:16` in NLGLOB14Z8.

## Purpose

Extend the qualified split accepted-state trajectory through the independently confirmed physical retreat:

`10:16 -> 11:16`

and move temporal ownership only from its own accepted state:

`face 9/10 -> face 10/11`.

## Frozen fixtures

Use O05:

- HEAD, dt = 1.25e-4 d;
- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 1.25e-4 d;
- RUNOFF, dt = 6.25e-5 d;
- scientific horizon = 60.0 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged split-domain formulation;
- provider-faithful dry top;
- control trajectory only as diagnostic comparator.

## Ownership authority

At every accepted split state derive the lower saturated tail from exact accepted physical state:

- `h >= 0`;
- `theta == theta_s`.

Ownership changes only after the split trajectory itself accepts:

`10:16 -> 11:16`.

No control time, predictor state, fitted threshold, epsilon, hysteresis or count-only heuristic may trigger ownership.

## Execution partition

The 60.0 d scientific trajectory is transported through two exact sequential execution segments for each fixture:

1. segment A: origin -> 30.0 d;
2. exact accepted-state checkpoint at 30.0 d;
3. segment B: 30.0 -> 60.0 d.

Checkpoint transport must preserve exactly:

- pressure-head vector;
- water-content vector;
- accepted saturated-tail geometry;
- temporal ownership;
- accepted event history;
- counters and diagnostic maxima.

This is infrastructure partition only. It does not change the mathematical trajectory.

## Checkpoint gates

Require:

- h roundtrip bit-exact;
- theta roundtrip bit-exact;
- restored tail identical;
- restored ownership identical;
- no synthetic event at 30.0 d;
- segment-B first interval starts from exact segment-A accepted endpoint.

## Hard scientific gates

Per fixture require:

- complete 60.0 d trajectory;
- exact accepted `10:16 -> 11:16`;
- exact one-face ownership move `9/10 -> 10/11`;
- residual <= 1e-10;
- interval mass ledger <= 5e-8 cm;
- exact rollback;
- no chatter/reverse;
- no skipped face;
- contiguous accepted saturated geometry;
- provider-faithful dry top.

## Frozen classifications

If all four fixtures qualify:

`QUALIFIED_SPLIT_RETREAT_10_TO_11_OWNERSHIP_TRANSITION`.

If valid trajectories complete but event is not reached:

`NLGLOB14Z11_SPLIT_RETREAT_NOT_REACHED`.

Any checkpoint continuity failure:

`NLGLOB14Z11_CHECKPOINT_CONTINUITY_INVALID`.

Any chatter/reverse:

`NLGLOB14Z11_INTERFACE_CHATTER`.

Any skipped/noncontiguous geometry:

`NLGLOB14Z11_GEOMETRY_INCONSISTENT`.

Any coupling failure with clean rollback:

`NLGLOB14Z11_COUPLING_NOT_CLOSED`.

Any mass/transaction leak:

`NLGLOB14Z11_TRANSACTION_INCONSISTENT`.

## Consequence

Positive Z11 qualifies split ownership through accepted saturated tail `11:16`.

It does not qualify:

- later retreats beyond 11:16;
- complete saturated-block disappearance;
- empty-tail transition;
- whole-column TG re-entry;
- production temporal ownership.

## Production boundary

Research only. No production source/default change.
