# F-PE-NLGLOB14Z preregistration — saturated-block disappearance control exposure

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

Parent research authority:

- NLGLOB14X: `QUALIFIED_FURTHER_MONOTONE_RETREAT_CONTROL_EXPOSURE`;
- NLGLOB14Y: `QUALIFIED_SPLIT_MULTI_RETREAT_OWNERSHIP_SEQUENCE`;
- accepted physical control retreat sequence through 0.80 d:
  - `4:16 -> 5:16`;
  - `5:16 -> 6:16`;
  - `6:16 -> 7:16`;
- complete disappearance is not observed by 0.80 d.

## Purpose

Determine whether the persistent lower saturated block eventually disappears under the same unchanged dry forcing, and expose the accepted physical disappearance state before any whole-column TG re-entry is tested.

This workunit is control-only.

## Frozen fixtures

Use O05 persistent-KLAG control with:

- HEAD and RUNOFF entry families;
- dt = 2.5e-4, 1.25e-4, 6.25e-5 and 3.125e-5 d;
- unchanged NLGLOB14N3 root-controller research policy;
- unchanged NLGLOB14G/L dry forcing;
- unchanged zero bottom flux;
- accepted physical state and mass as authority.

## Frozen staged horizons

Continue the same control trajectory with fixed horizons:

- stage 1: 1.6 d;
- if not all fixtures reach disappearance: stage 2 = 3.2 d;
- if still not all disappear: stage 3 = 6.4 d.

Stop after the first stage where all eight fixtures expose complete disappearance.

Do not extend beyond 6.4 d in this workunit.

Horizon selection is independent of split behavior.

## Physical state definition

At every accepted state define saturation only by:

- `h_i >= 0`;
- `theta_i == theta_s,i`.

When nonempty, the saturated set must be a contiguous tail ending at node 16.

Complete disappearance is the first accepted state with an empty saturated set.

Record every accepted one-node retreat after 7:16.

No pressure threshold, theta epsilon, count-only heuristic, interpolation or predictor crossing defines disappearance.

## Required diagnostics

Per fixture:

- final selected horizon;
- complete/finite/mass-clean status;
- accepted saturated-tail sequence after 7:16;
- time of each later retreat;
- first empty accepted saturated set;
- last nonempty set and time;
- disappearance bracket;
- any reverse expansion after 7:16;
- any skipped node;
- any noncontiguous state;
- max interval and cumulative physical mass ledger.

## Frozen classifications

If all 8 fixtures reach empty accepted saturated set within 6.4 d with monotone contiguous retreat:

`QUALIFIED_SATURATED_BLOCK_DISAPPEARANCE_CONTROL_EXPOSURE`.

If all remain valid and retreat further but at least one is still saturated at 6.4 d:

`QUALIFIED_LATE_MONOTONE_RETREAT_WITHOUT_DISAPPEARANCE`.

If no fixture retreats beyond 7:16:

`NLGLOB14Z_NO_LATE_RETREAT_WITHIN_6P4D`.

If reverse expansion occurs after the established retreat sequence:

`NLGLOB14Z_LATE_RETREAT_REVERSAL`.

If a node is skipped or geometry becomes noncontiguous:

`NLGLOB14Z_LATE_RETREAT_GEOMETRY_INCONSISTENT`.

If process or mass fails:

`BLOCKED_NLGLOB14Z_DISAPPEARANCE_CONTROL`.

Mixed otherwise-valid disappearance coverage:

`NLGLOB14Z_MIXED_DISAPPEARANCE_EXPOSURE`.

## Consequence boundary

A positive disappearance result authorizes a successor that carries the split accepted-state trajectory through the independently exposed remaining retreats to an empty saturated set.

Only after the split trajectory itself reaches accepted disappearance may a separately preregistered whole-column TG re-entry test be opened.

NLGLOB14Z does not authorize re-entry.

## Stop rules

Do not:

- change dry forcing;
- alter dt;
- fit disappearance thresholds;
- infer disappearance from predictor state;
- use split behavior to select horizon;
- modify production source.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Z

BASELINE: `3bafe9673773f7f8df0394fca6a66c177e9fb8bb`

BRANCH: `research/f-pe-nlglob14z-disappearance-control`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: run staged persistent-KLAG disappearance exposure through at most 6.4 d.

## Production boundary

Research only. No production source or default policy changes.
