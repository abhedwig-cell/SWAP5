# F-PE-NLGLOB14Z6 preregistration — split ownership through 8:16 -> 9:16

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent research authority:

- NLGLOB14Z4: `QUALIFIED_NEXT_LATE_RETREAT_CONTROL_EXPOSURE`;
- NLGLOB14Z5: `QUALIFIED_SPLIT_LATE_RETREAT_OWNERSHIP_TRANSITION`;
- split accepted state reaches `8:16` by 2.80 d;
- control exposes accepted `8:16 -> 9:16` near 7.65 d on both retained complete dt levels.

## Purpose

Extend the qualified split accepted-state trajectory through the independently exposed physical retreat:

`8:16 -> 9:16`

and move temporal ownership only from the split trajectory's own accepted state:

`face 7/8 -> face 8/9`.

## Frozen fixtures

Use O05:

- HEAD and RUNOFF;
- dt = 1.25e-4 d and 6.25e-5 d;
- fixed horizon = 12.80 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged qualified split-domain formulation from NLGLOB14Y/Z5;
- provider-faithful dynamic top;
- persistent-KLAG control on the same fixture only as comparator.

## Ownership authority

At every accepted split state derive the contiguous lower saturated tail exactly from:

- `h >= 0`;
- `theta == theta_s`.

Ownership changes only after the split trajectory itself changes:

`8:16 -> 9:16`.

No control event time, predictor state, fitted pressure threshold, theta epsilon, hysteresis or count-only heuristic may trigger the move.

## Hard gates

Per fixture require:

- complete 12.80 d trajectory;
- finite accepted state;
- node residual <= `1e-10`;
- interval physical mass ledger <= `5e-8 cm`;
- exact rollback of rejected candidates;
- contiguous lower saturated geometry;
- exact one-face ownership move `7/8 -> 8/9`;
- no reverse/chatter;
- no skipped face;
- provider-faithful dry top semantics.

## Frozen classifications

If all four fixtures cross exact accepted `8:16 -> 9:16` and ownership moves cleanly:

`QUALIFIED_SPLIT_NEXT_LATE_RETREAT_OWNERSHIP_TRANSITION`.

If valid trajectories complete but do not reach the retreat:

`NLGLOB14Z6_SPLIT_NEXT_RETREAT_NOT_REACHED`.

Any chatter/reverse:

`NLGLOB14Z6_NEXT_LATE_INTERFACE_CHATTER`.

Any skipped/noncontiguous geometry:

`NLGLOB14Z6_NEXT_LATE_GEOMETRY_INCONSISTENT`.

Any coupling failure with clean rollback:

`NLGLOB14Z6_NEXT_LATE_COUPLING_NOT_CLOSED`.

Any mass/transaction leak:

`NLGLOB14Z6_NEXT_LATE_TRANSACTION_INCONSISTENT`.

## Consequence

A positive result qualifies state-driven split ownership through one additional late retreat to accepted saturated tail `9:16`.

It still does not qualify:

- later retreats beyond 9:16;
- complete saturated-block disappearance;
- whole-column TG re-entry;
- production temporal ownership.

## Stop rules

Do not:

- impose control event times;
- change forcing or dt;
- fit thresholds;
- tune solver tolerances;
- replay control top fluxes;
- duplicate interface flux authority;
- modify production source.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Z6

BASELINE: `2da6f2da8e52e02b2233a75ad214b02f67916d1c`

BRANCH: `research/f-pe-nlglob14z6-split-next-late-retreat`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: extend the qualified Z5 split trajectory to 12.80 d and test state-derived ownership through `8:16 -> 9:16`.

## Production boundary

Research only. No production source or default policy changes.
