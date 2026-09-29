# F-PE-NLGLOB14Z preregistration — late saturated-block retreat and disappearance control exposure

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

Parent research authority:

- NLGLOB14X: `QUALIFIED_FURTHER_MONOTONE_RETREAT_CONTROL_EXPOSURE`;
- NLGLOB14Y: `QUALIFIED_SPLIT_MULTI_RETREAT_OWNERSHIP_SEQUENCE`;
- accepted physical control retreat sequence is established through:
  - `4:16 -> 5:16` near 0.106 d;
  - `5:16 -> 6:16` near 0.247-0.251 d;
  - `6:16 -> 7:16` near 0.728-0.731 d;
- the split research trajectory follows those moves with state-derived ownership and no chatter;
- complete saturated-block disappearance is not observed by 0.80 d.

## Purpose

Expose the later accepted physical lifecycle of the persistent lower saturated block under exactly the same dry forcing.

Primary questions:

1. does the saturated tail continue to retreat beyond `7:16`?
2. are later retreats monotone, contiguous and one-node-at-a-time?
3. does the saturated set become empty within a bounded unchanged-forcing horizon?
4. if disappearance occurs, what is the accepted-state disappearance bracket?

This workunit is independent control observation only. It does not run the split solver and does not test TG re-entry.

## Frozen fixtures

Use O05 persistent saturated-KLAG control:

- HEAD and RUNOFF entry families;
- dt = 2.5e-4, 1.25e-4, 6.25e-5 and 3.125e-5 d;
- unchanged NLGLOB14N3 root-controller research policy;
- unchanged NLGLOB14G/L dry forcing;
- unchanged zero bottom flux;
- physical mass as hard authority.

## Frozen staged horizons

Run the same bank in this fixed sequence:

1. 1.60 d;
2. if no fixture reaches disappearance, 3.20 d;
3. if no fixture reaches disappearance, 6.40 d.

Stop after the first stage at which all 8 fixtures expose disappearance.

If disappearance remains absent at 6.40 d, close that bounded negative result. Do not extend further inside NLGLOB14Z.

Stage progression depends only on absence of accepted physical disappearance in the independent control.

## Physical saturated-set definition

At every accepted persistent-mode state, node `i` is saturated only when both exact indicators hold:

- `h_i >= 0`;
- `theta_i == theta_s,i`.

Whenever nonempty, the saturated set must be a contiguous tail ending at node 16.

Record every accepted saturated-tail transition after the already qualified `7:16` state.

A valid retreat changes the top saturated node by exactly +1.

Complete disappearance is the first accepted state with an empty saturated set.

No fitted pressure threshold, theta epsilon, predictor-only crossing, count heuristic or hysteresis is allowed.

## Required diagnostics

Per fixture record:

- selected horizon;
- complete/finite/mass-clean status;
- all accepted tail transitions after `7:16`;
- accepted time of every later retreat;
- any reverse expansion after `7:16`;
- any skipped top node;
- any noncontiguous geometry;
- disappearance time, if present;
- last nonempty set/time and first empty set/time;
- final saturated set;
- max accepted-interval mass ledger;
- cumulative physical mass ledger.

## Frozen classifications

If all 8 fixtures remain valid and reach empty saturated set within 6.40 d:

`QUALIFIED_SATURATED_BLOCK_DISAPPEARANCE_CONTROL_EXPOSURE`.

If all 8 remain valid, all show at least one further retreat beyond `7:16`, but one or more retain saturation at 6.40 d:

`QUALIFIED_LATE_MONOTONE_RETREAT_CONTROL_EXPOSURE`.

If all remain valid but no fixture retreats beyond `7:16` by 6.40 d:

`NLGLOB14Z_NO_LATE_RETREAT_WITHIN_6P40D`.

Any reverse accepted expansion after the established `7:16` state:

`NLGLOB14Z_LATE_RETREAT_REVERSAL_OBSERVED`.

Any skipped-node or noncontiguous accepted geometry:

`NLGLOB14Z_LATE_RETREAT_GEOMETRY_INCONSISTENT`.

Any control process, finite-state or mass failure:

`BLOCKED_NLGLOB14Z_CONTROL_EXPOSURE`.

Mixed otherwise-valid disappearance coverage:

`NLGLOB14Z_MIXED_DISAPPEARANCE_EXPOSURE`.

## Consequence boundary

A positive late-retreat result authorizes a successor carrying accepted split ownership through those independently exposed later transitions.

A full disappearance result additionally authorizes, but does not itself perform:

1. split ownership through the complete disappearance event;
2. only after that succeeds, a separately preregistered whole-column TG re-entry study from an accepted empty-saturated-set state.

## Stop rules

Do not:

- alter forcing;
- alter dt;
- tune solver tolerances;
- infer disappearance from predictor state;
- use split behavior to select horizon;
- fit release thresholds;
- modify production `src/**`.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Z

BASELINE: `3bafe9673773f7f8df0394fca6a66c177e9fb8bb`

BRANCH: `research/f-pe-nlglob14z-disappearance-exposure`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: run staged persistent-KLAG control exposure to 1.6/3.2/6.4 d.

## Production boundary

Research only. No production source or default policy changes.
