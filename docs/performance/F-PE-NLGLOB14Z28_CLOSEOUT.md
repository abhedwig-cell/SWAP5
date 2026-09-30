# F-PE-NLGLOB14Z28 closeout — variable-dimension manager bootstrap

Date: 2026-09-30

Final status:

`QUALIFIED_Z28_VARIABLE_DIMENSION_MANAGER_BOOTSTRAP`

Qualification authority:

- successful workflow run `36730098775`;
- successful job `109937108754`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

## Closure

Z28 closes positively.

The production reference workspace and TRIDAG primitives already support genuine variable algebra dimension under `active_nodes`.

The frozen reshape sequence:

`12 -> 11 -> 12 -> 13 -> 12`

executes without stale-state leakage or fixed-16 fallback.

Compared with the n=16 control, exact structural TRIDAG row work is reduced to approximately:

- 67.7% at n=11;
- 74.2% at n=12;
- 80.6% at n=13.

Workspace payload decreases monotonically with active dimension.

## Strategic consequence

The line has now crossed an important boundary.

The physical moving-interface semantics are qualified, and the production solver infrastructure can actually exploit the reduced dimension.

The next step should therefore be the first physical production-shaped adaptive-manager binding and A/B benchmark against the full-column reference.

Do not spend additional work on chatter-specific suppression unless new evidence requires it.

## Direct successor

Open:

`F-PE-NLGLOB14Z29 — production-shaped adaptive moving-interface physical A/B benchmark`.

The successor must preserve the Z20-Z26 physical authority and use the Z28 variable-dimension production primitives.

It must compare adaptive versus full-column reference on identical O05 trajectories and report both physical equivalence and performance/work reduction.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z28

BRANCH: `research/f-pe-nlglob14z28-variable-dimension-manager`

RESEARCH POSTIMAGE BEFORE CLOSEOUT: `9b20858f7e5839c8331a0cf22e101dde22a649d2`

QUALIFICATION STATUS: `QUALIFIED_Z28_VARIABLE_DIMENSION_MANAGER_BOOTSTRAP`

NEXT SAFE STEP: Z29 physical adaptive-manager binding and A/B benchmark.

## Production boundary

No production default change.

`LEGACY_NUMERICS` remains production default.
