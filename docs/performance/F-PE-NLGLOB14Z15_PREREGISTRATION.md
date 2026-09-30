# F-PE-NLGLOB14Z15 preregistration — split ownership through 12:16 -> 13:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authority:

- NLGLOB14Z14 preserves one unmodified accepted `12:16 -> 13:16` control event;
- NLGLOB14Z14C: `QUALIFIED_Z14C_THREE_REPAIRED_RETREAT_12_TO_13`;
- together these restore four-fixture research authority for exact accepted `12:16 -> 13:16`;
- split ownership is qualified through accepted tail `12:16` in NLGLOB14Z13.

## Purpose

Extend the qualified split accepted-state trajectory through:

`12:16 -> 13:16`

and move temporal ownership only from the split trajectory's own accepted state:

`face 11/12 -> face 12/13`.

## Frozen fixtures

Use O05:

- HEAD, dt = 1.25e-4 d;
- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 1.25e-4 d;
- RUNOFF, dt = 6.25e-5 d;
- scientific horizon = 280.0 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged split-domain formulation;
- provider-faithful dry top;
- control trajectory only as diagnostic comparator.

The fine-RUNOFF control comparator is explicitly the Z14C repaired research trajectory under the already qualified one-level local-retry policy.

## Ownership authority

At every accepted split state derive the lower saturated tail exactly from accepted physical state:

- `h >= 0`;
- `theta == theta_s`.

Ownership moves only after the split trajectory itself accepts:

`12:16 -> 13:16`.

No control event time, predictor state, fitted threshold, epsilon, hysteresis or count-only heuristic may trigger ownership.

## Execution partition

The 280.0 d scientific trajectory is transported through two exact sequential execution segments per fixture:

1. segment A: origin -> 140.0 d;
2. exact accepted-state checkpoint at 140.0 d;
3. segment B: 140.0 -> 280.0 d.

The checkpoint must preserve exactly:

- pressure-head vector;
- water-content vector;
- accepted saturated-tail geometry;
- temporal ownership;
- accepted event history;
- accepted interval counters;
- diagnostic maxima for mass, residual and rollback.

Execution partition is infrastructure transport only and does not change the mathematical trajectory.

## Checkpoint gates

Require:

- h roundtrip bit-exact;
- theta roundtrip bit-exact;
- restored saturated tail identical;
- restored ownership identical;
- no synthetic event at 140.0 d;
- segment-B first interval starts from exact segment-A accepted endpoint.

## Hard scientific gates

Per fixture require:

- complete 280.0 d trajectory;
- exact accepted `12:16 -> 13:16`;
- exact one-face ownership move `11/12 -> 12/13`;
- residual <= 1e-10;
- interval physical mass ledger <= 5e-8 cm;
- exact rollback;
- no chatter/reverse;
- no skipped face;
- contiguous accepted saturated geometry;
- provider-faithful dry top.

## Frozen classifications

If all four fixtures qualify:

`QUALIFIED_SPLIT_RETREAT_12_TO_13_OWNERSHIP_TRANSITION`.

If valid trajectories complete but event is not reached:

`NLGLOB14Z15_SPLIT_RETREAT_NOT_REACHED`.

Any checkpoint continuity failure:

`NLGLOB14Z15_CHECKPOINT_CONTINUITY_INVALID`.

Any chatter/reverse:

`NLGLOB14Z15_INTERFACE_CHATTER`.

Any skipped/noncontiguous geometry:

`NLGLOB14Z15_GEOMETRY_INCONSISTENT`.

Any coupling failure with clean rollback:

`NLGLOB14Z15_COUPLING_NOT_CLOSED`.

Any mass/transaction leak:

`NLGLOB14Z15_TRANSACTION_INCONSISTENT`.

## Consequence

Positive Z15 qualifies split ownership through accepted saturated tail `13:16`.

It does not qualify:

- later retreats beyond `13:16`;
- complete saturated-block disappearance;
- empty-tail transition;
- whole-column TG re-entry;
- production temporal ownership.

## Production boundary

Research only. No production source/default change.
