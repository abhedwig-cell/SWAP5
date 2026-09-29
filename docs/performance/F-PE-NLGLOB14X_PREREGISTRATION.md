# F-PE-NLGLOB14X preregistration — further saturated-block retreat and disappearance control exposure

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

Parent research authority:

- NLGLOB14V: `QUALIFIED_SECOND_RETREAT_CONTROL_EXPOSURE`;
- NLGLOB14W: `QUALIFIED_SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION`;
- the persistent-KLAG control exposes accepted 4:16 -> 5:16 retreat near 0.106 d;
- the split accepted-state trajectory follows that event with face 3/4 -> 4/5 without chatter or fitted thresholds.

## Purpose

Expose the subsequent physical saturated-block lifecycle independently in the persistent-KLAG control before asking the split formulation to follow further ownership moves.

Primary questions:

1. does the accepted lower saturated block continue to retreat beyond nodes 5:16?
2. is retreat monotone and contiguous?
3. does the saturated block disappear completely within a bounded unchanged-forcing horizon?
4. if disappearance occurs, at what accepted-state bracket does it occur?

This workunit does not alter or run the split ownership solver.

## Frozen fixtures

Use O05 persistent-KLAG control with:

- HEAD and RUNOFF entry families;
- dt = 2.5e-4, 1.25e-4, 6.25e-5 and 3.125e-5 d;
- unchanged NLGLOB14N3 root-controller research policy;
- unchanged NLGLOB14G/L dry forcing;
- unchanged zero bottom flux;
- physical mass as authority.

## Frozen staged horizons

Run the same control bank in stages:

- stage 1: 0.20 d;
- if no fixture reaches complete saturated-block disappearance: stage 2 = 0.40 d;
- if still no fixture reaches disappearance: stage 3 = 0.80 d.

The stage progression depends only on absence of physical disappearance in the independent control.

Do not extend beyond 0.80 d in this workunit.

## Physical state definition

At every accepted persistent-mode state define the saturated set only from the exact paired constitutive indicators:

- `h_i >= 0`;
- `theta_i == theta_s,i`.

Whenever nonempty, the saturated set must remain a contiguous tail ending at node 16.

Record every accepted change in top saturated node:

`k:16 -> (k+1):16`.

Complete disappearance is the first accepted state with no saturated node.

No fitted pressure threshold, theta epsilon, hysteresis or predictor-only crossing is permitted.

## Required diagnostics

Per fixture record:

- selected final horizon;
- complete/finite/mass-clean status;
- ordered accepted saturated-top sequence;
- accepted times of every retreat;
- any reverse expansion after a retreat;
- any skipped retreat, e.g. 5:16 -> 7:16 in one accepted interval;
- any noncontiguous geometry;
- disappearance time/bracket if present;
- final saturated set;
- max interval and cumulative physical mass ledger.

## Frozen classifications

If all 8 fixtures preserve valid monotone contiguous retreat and all reach disappearance within 0.80 d:

`QUALIFIED_SATURATED_BLOCK_DISAPPEARANCE_CONTROL_EXPOSURE`.

If all 8 remain valid and show one or more further retreats beyond 5:16 but at least one does not disappear by 0.80 d:

`QUALIFIED_FURTHER_MONOTONE_RETREAT_CONTROL_EXPOSURE`.

If all remain valid but no fixture retreats beyond 5:16 by 0.80 d:

`NLGLOB14X_NO_FURTHER_RETREAT_WITHIN_0P80D`.

Any reverse accepted expansion after established retreat:

`NLGLOB14X_RETREAT_REVERSAL_OBSERVED`.

Any noncontiguous or skipped accepted geometry:

`NLGLOB14X_RETREAT_GEOMETRY_INCONSISTENT`.

Any process or physical-mass failure:

`BLOCKED_NLGLOB14X_CONTROL_EXPOSURE`.

Mixed otherwise-valid disappearance coverage:

`NLGLOB14X_MIXED_DISAPPEARANCE_EXPOSURE`.

## Consequence boundary

A positive monotone-retreat result authorizes a successor that carries accepted split ownership through the independently exposed retreat sequence.

A full disappearance result additionally authorizes, only after split ownership itself reaches disappearance, a separately preregistered whole-column TG re-entry study.

NLGLOB14X itself does not authorize TG re-entry.

## Stop rules

Do not:

- tune dry forcing;
- alter dt;
- introduce release thresholds;
- infer disappearance from predictor state;
- run split ownership to select the horizon;
- modify production source.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14X

BASELINE: `8e7c22c1a0dd74867bd1918a3d87063e8be095a0`

BRANCH: `research/f-pe-nlglob14x-further-retreat-exposure`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: implement staged persistent-KLAG lifecycle exposure and run the 8-fixture bank.

## Production boundary

Research only. No production source or default policy changes.
