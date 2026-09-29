# F-PE-NLGLOB14X closeout — further saturated-block retreat exposure

Date: 2026-09-29

Final status:

`QUALIFIED_FURTHER_MONOTONE_RETREAT_CONTROL_EXPOSURE`

Qualification authority:

- run `36605738694`;
- job `109534152914`;
- conclusion: SUCCESS.

## Closure

NLGLOB14X closes positively for further physical retreat exposure.

After the independently qualified second retreat, all 8 persistent-KLAG controls show the same monotone accepted-state sequence:

`5:16 -> 6:16 -> 7:16`.

The third retreat occurs near 0.247-0.251 d.

The fourth retreat occurs near 0.728-0.731 d.

No post-second-retreat reversal, skipped node, noncontiguous geometry, state inconsistency or mass failure occurs.

## Disappearance boundary

No fixture reaches complete saturated-block disappearance by the preregistered maximum 0.80 d horizon.

The final accepted saturated set is nodes 7:16 in every fixture.

NLGLOB14X therefore does not authorize whole-column TG re-entry.

## Direct successor

Open a split accepted-state successor that runs through the same 0.80 d horizon and tests two additional state-driven ownership moves:

- `face 4/5 -> 5/6` when `5:16 -> 6:16`;
- `face 5/6 -> 6/7` when `6:16 -> 7:16`.

Control event times are comparators only.

The split trajectory must derive every move from its own accepted physical state and remain conservative, transaction-safe and chatter-free.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14X

BASELINE: `8e7c22c1a0dd74867bd1918a3d87063e8be095a0`

BRANCH: `research/f-pe-nlglob14x-further-retreat-exposure`

QUALIFICATION RUN: `36605738694`

STATUS: closed positive research qualification

QUALIFICATION STATUS: `QUALIFIED_FURTHER_MONOTONE_RETREAT_CONTROL_EXPOSURE`

NEXT SAFE STEP: preregister split ownership through the third and fourth independently exposed retreats.

## Production boundary

No production source or default policy change.
