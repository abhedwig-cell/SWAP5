# F-PE-NLGLOB13D result — same-origin h/8 falsification

Date: 2026-09-29

Status:

`NLGLOB13D_H8_ADMISSIBILITY_NOT_CONFIRMED`

Canonical experiment base:

`integration/f-ci-canonical@dc12c52ea71e136cd9ea0573980915b8618ca7d6`

Authority corrected after harness reconciliation against canonical through:

`integration/f-ci-canonical@3b1488c0d2723f9ec02709693406b4ecb45377ea`

Qualification authority:

- workflow run: `36558791581`;
- job: `109374338130`;
- conclusion: SUCCESS.

## Frozen question

Does one additional bounded same-origin subdivision level, from a failing h/4 child to two h/8 children, make the five remaining O05/TG near-saturation targets retention-admissible?

No h/16 or recursive subdivision was permitted.

## Coverage

PASS.

All five frozen targets executed without process failure:

- HEAD, dt 0.00025 d;
- HEAD, dt 0.000125 d;
- HEAD, dt 0.0000625 d;
- RUNOFF, dt 0.00025 d;
- RUNOFF, dt 0.000125 d.

Smooth TIMEINT16C authority remains preserved:

- median refined top-head order about `2.04787`;
- median refined top-theta order about `2.04787`;
- smooth qualification gate PASS.

Physical mass remains within authority on all trajectories.

## Result

No target completes the full requested horizon.

At the first same-origin h/8 child:

- `1/5` becomes retention-admissible;
- `4/5` remain retention-inadmissible;
- completed full targets: `0/5`;
- completed bounded h/8 subdivision pairs: `0/5`.

The preregistered negative gate therefore still applies.

No process failure, nonfinite-state failure or physical-mass failure is observed.

## Frozen classification

`NLGLOB13D_H8_ADMISSIBILITY_NOT_CONFIRMED`.

The preregistered negative gate applies because at least 3/5 first h/8 children remain inadmissible. The corrected final run observes 4/5.

## Interpretation

The near-saturation TG accepted-state defect contracts under temporal refinement, as established by NLGLOB13C2, but simple bounded subdivision through h/8 is still insufficient to remove it.

This rules out subdivision depth alone as a practical repair for this line.

The failure is not caused by:

- endpoint nonconvergence;
- mass imbalance;
- route mismatch;
- nonfinite state;
- loss of smooth second-order behavior.

The remaining issue is the accepted TG temporal construction at the saturation boundary.

## Consequence

Do not open h/16 or adaptive recursive subdivision as a continuation of this workunit.

A successor must use a different temporal construction tied explicitly to the saturation boundary, while preserving:

- provider-consistent endpoint coefficient staging;
- unchanged accepted-state mass accounting;
- no accepted-theta clipping;
- smooth second-order authority away from the event;
- explicit route/event semantics.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
