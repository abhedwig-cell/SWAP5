# F-PE-NLGLOB14Y preregistration — split ownership across third and fourth retreats

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

Parent research authority:

- NLGLOB14W: `QUALIFIED_SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION`;
- NLGLOB14X: `QUALIFIED_FURTHER_MONOTONE_RETREAT_CONTROL_EXPOSURE`;
- control exposes accepted physical sequence:
  - `5:16 -> 6:16` near 0.247-0.251 d;
  - `6:16 -> 7:16` near 0.728-0.731 d;
- no post-second-retreat reversal, skipped node or noncontiguous control geometry is observed;
- complete saturated-block disappearance is not observed by 0.80 d.

## Purpose

Test whether the accepted split-domain research trajectory can follow two additional independently exposed physical lower-edge retreats and move ownership sequentially:

- `face 4/5 -> face 5/6`;
- `face 5/6 -> face 6/7`;

solely from its own accepted physical saturated set.

The persistent-KLAG control times are comparators only. They are not switch times.

## Frozen fixtures

Use O05:

- HEAD and RUNOFF entry families;
- dt = 2.5e-4, 1.25e-4, 6.25e-5 and 3.125e-5 d;
- fixed horizon = `0.80 d`;
- unchanged NLGLOB14G/L dry forcing;
- unchanged zero bottom flux;
- first-retreat accepted state as split sequence origin;
- provider-faithful dynamic top;
- persistent-KLAG control on the same fixture only for matched state/event comparison.

## Split formulation and ownership

Retain the qualified NLGLOB14T/W formulation unchanged:

- one coupled full-profile endpoint state;
- TG/trapezoidal treatment above the accepted lower saturated block;
- saturated/full-Richards treatment in the lower block;
- exactly one physical Darcy exchange per interface face;
- one shared temporal interface exchange integral;
- provider-faithful dry top boundary;
- zero qbot;
- no residual redistribution.

At every accepted state derive the lower saturated tail from exact physical state indicators.

Ownership moves only after an accepted state changes the contiguous saturated tail.

Expected target sequence after the second retreat:

`5:16 -> 6:16 -> 7:16`.

Corresponding faces:

`4/5 -> 5/6 -> 6/7`.

No control time, h threshold, theta threshold, count-only heuristic or hysteresis is allowed to trigger a move.

## Transaction contract

Every interval remains a private research transaction.

Commit a candidate only if:

- finite;
- residual <= `1e-10`;
- interval and cumulative mass ledger <= `5e-8 cm`;
- accepted saturated geometry is contiguous;
- dynamic-top semantics remain within the frozen dry provider profile;
- no interface authority is duplicated.

Rejected candidates must leave the previous accepted research state exactly unchanged.

## Required diagnostics

Per fixture:

- all accepted ownership transitions and times;
- control transition times;
- split-control event-time differences;
- pre/post accepted saturated sets;
- pre/post ownership faces;
- any reverse interface move;
- any skipped interface move;
- any noncontiguous geometry;
- max interval/cumulative physical mass ledger;
- max residual;
- rollback differences;
- matched split/control head/theta differences;
- final saturated set at 0.80 d.

## Frozen classifications

A fixture qualifies `SPLIT_MULTI_RETREAT_SEQUENCE_VALID` only if:

1. it reaches 0.80 d;
2. it contains both exact accepted transitions:
   - `5:16 -> 6:16`;
   - `6:16 -> 7:16`;
3. ownership moves exactly one face each time;
4. no reverse move occurs afterward;
5. no skipped or noncontiguous accepted geometry occurs;
6. all mass, residual, dynamic-top and transaction gates pass.

If all 8 fixtures qualify:

`QUALIFIED_SPLIT_MULTI_RETREAT_OWNERSHIP_SEQUENCE`.

If some valid trajectories fail to reach one of the two physical transitions by 0.80 d:

`NLGLOB14Y_SPLIT_RETREAT_SEQUENCE_NOT_COMPLETE`.

If ownership reverses or oscillates:

`NLGLOB14Y_MULTI_RETREAT_INTERFACE_CHATTER`.

If a node/face is skipped or geometry becomes noncontiguous:

`NLGLOB14Y_MULTI_RETREAT_GEOMETRY_INCONSISTENT`.

If coupled progression fails while rollback remains clean:

`NLGLOB14Y_MULTI_RETREAT_COUPLING_NOT_CLOSED`.

If mass or state authority leaks:

`NLGLOB14Y_MULTI_RETREAT_TRANSACTION_INCONSISTENT`.

If dry top semantics are not preserved:

`NLGLOB14Y_DYNAMIC_TOP_NOT_PRESERVED`.

Mixed otherwise-valid outcomes:

`NLGLOB14Y_MIXED_MULTI_RETREAT_SEQUENCE`.

## Consequence boundary

A positive result establishes repeated state-driven moving-interface operation across three total post-peak retreat events, including the previously qualified second retreat and the two new control-exposed retreats.

It still does not qualify:

- complete saturated-block disappearance;
- whole-column TG re-entry;
- production temporal ownership.

Those remain future work.

## Stop rules

Do not:

- impose control event times;
- change forcing or dt;
- fit thresholds or hysteresis;
- tune solver tolerances to force retreat;
- replay control top fluxes;
- freeze lower heads;
- duplicate interface flux authority;
- modify production `src/**`.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Y

BASELINE: `f8fc0ce1fdd89e6a47e52cedd983d9ff26397a3e`

BRANCH: `research/f-pe-nlglob14y-multi-retreat-split`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: carry the qualified split accepted-state formulation through the independently exposed third and fourth retreats.

## Production boundary

Research only. No production source or default policy changes.
