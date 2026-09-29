# F-PE-NLGLOB14U closeout — accepted-state moving-interface split evolution

Date: 2026-09-29

Final status:

`NLGLOB14U_ACCEPTED_SPLIT_EVOLUTION_WITHOUT_INTERFACE_MOTION`

Qualification authority:

- run `36603872043`;
- job `109527798184`;
- conclusion: SUCCESS.

## Closure

NLGLOB14U closes the multi-interval acceptance question positively but does not yet close the interface-motion question.

Across all 12 fixtures:

- 13,148 split intervals are accepted;
- 0 are rejected;
- physical mass remains within `6.88e-10 cm`;
- maximum nonlinear residual remains within `6.74e-11`;
- rollback leakage is zero;
- dynamic top remains provider-consistent on `surface-flux`;
- there is no interface chatter.

The accepted saturated block remains nodes 4:16 through the frozen `0.05 d` horizon in every fixture.

## Qualified statement

The research split-domain temporal ownership is stable as a repeated accepted-state evolution after first retreat.

This is stronger than NLGLOB14T's one-interval shadow qualification.

It still does not demonstrate an ownership-face move, because no second physical retreat occurs in the frozen horizon.

## Direct successor

Use a separately preregistered fixed-horizon extension under exactly the same:

- dry forcing magnitude;
- dynamic-top provider semantics;
- dt fixtures;
- split residual;
- transaction gates;
- accepted-state ownership rule.

The next study should seek the next accepted retreat of node 4 and determine whether face 3/4 moves to 4/5 without chatter.

No numerical or physical parameter may be tuned to produce that event.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14U

BRANCH: `research/f-pe-nlglob14u-accepted-moving-interface`

QUALIFICATION RUN: `36603872043`

STATUS: closed research result

QUALIFICATION STATUS: `NLGLOB14U_ACCEPTED_SPLIT_EVOLUTION_WITHOUT_INTERFACE_MOTION`

NEXT SAFE STEP: fixed longer-horizon accepted split evolution under unchanged forcing.

## Production boundary

No production source or default policy change.
