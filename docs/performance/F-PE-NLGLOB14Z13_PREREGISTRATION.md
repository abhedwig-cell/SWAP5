# F-PE-NLGLOB14Z13 preregistration — split ownership through 11:16 -> 12:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authority:

- NLGLOB14Z12 preserves accepted `11:16 -> 12:16` evidence in three controls;
- NLGLOB14Z12C: `QUALIFIED_REPAIRED_FINE_RUNOFF_RETREAT_11_TO_12`;
- together these restore four-fixture research authority for exact accepted `11:16 -> 12:16`;
- split ownership is qualified through accepted tail `11:16` in NLGLOB14Z11.

## Purpose

Extend the qualified split accepted-state trajectory through the independently established physical retreat:

`11:16 -> 12:16`

and move temporal ownership only from the split trajectory's own accepted state:

`face 10/11 -> face 11/12`.

## Frozen fixtures

Use O05:

- HEAD, dt = 1.25e-4 d;
- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 1.25e-4 d;
- RUNOFF, dt = 6.25e-5 d;
- scientific horizon = 140.0 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged split-domain formulation;
- provider-faithful dry top;
- control trajectory only as diagnostic comparator.

## Ownership authority

At each accepted split state, derive the lower saturated tail exactly from accepted physical state:

- `h >= 0`;
- `theta == theta_s`.

Ownership may move only after the split trajectory itself accepts:

`11:16 -> 12:16`.

No control time, predictor state, fitted threshold, epsilon, hysteresis or count-only heuristic may trigger ownership.

## Execution partition

The 140.0 d scientific trajectory is transported through two exact sequential execution segments per fixture:

1. segment A: origin -> 70.0 d;
2. exact accepted-state checkpoint at 70.0 d;
3. segment B: 70.0 -> 140.0 d.

Checkpoint transport must preserve exactly:

- pressure-head vector;
- water-content vector;
- accepted saturated-tail geometry;
- temporal ownership;
- accepted event history;
- accepted interval counters;
- diagnostic maxima for mass, residual and rollback.

The checkpoint is infrastructure transport only and does not change the mathematical trajectory.

## Checkpoint gates

Require:

- h roundtrip bit-exact;
- theta roundtrip bit-exact;
- restored saturated tail identical;
- restored temporal ownership identical;
- no synthetic event at 70.0 d;
- segment-B first interval starts from exact segment-A accepted endpoint.

## Hard scientific gates

Per fixture require:

- complete 140.0 d trajectory;
- exact accepted `11:16 -> 12:16`;
- exact one-face ownership move `10/11 -> 11/12`;
- residual <= 1e-10;
- interval physical mass ledger <= 5e-8 cm;
- exact rollback;
- no chatter/reverse;
- no skipped face;
- contiguous accepted saturated geometry;
- provider-faithful dry top.

## Frozen classifications

If all four fixtures qualify:

`QUALIFIED_SPLIT_RETREAT_11_TO_12_OWNERSHIP_TRANSITION`.

If valid trajectories complete but event is not reached:

`NLGLOB14Z13_SPLIT_RETREAT_NOT_REACHED`.

Any checkpoint continuity failure:

`NLGLOB14Z13_CHECKPOINT_CONTINUITY_INVALID`.

Any chatter/reverse:

`NLGLOB14Z13_INTERFACE_CHATTER`.

Any skipped/noncontiguous geometry:

`NLGLOB14Z13_GEOMETRY_INCONSISTENT`.

Any coupling failure with clean rollback:

`NLGLOB14Z13_COUPLING_NOT_CLOSED`.

Any mass/transaction leak:

`NLGLOB14Z13_TRANSACTION_INCONSISTENT`.

## Consequence

Positive Z13 qualifies split ownership through accepted saturated tail `12:16`.

It does not qualify:

- later retreats beyond `12:16`;
- complete saturated-block disappearance;
- empty-tail transition;
- whole-column TG re-entry;
- production temporal ownership.

## Production boundary

Research only. No production source/default change.
