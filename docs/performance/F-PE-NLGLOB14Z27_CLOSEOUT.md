# F-PE-NLGLOB14Z27 closeout — research harness is not performance-shaped

Date: 2026-09-30

Final status:

`QUALIFIED_Z27_RESEARCH_HARNESS_NOT_PERFORMANCE_SHAPED`

Qualification authority:

- workflow run `36729143355`;
- audit job `109933766937`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

## Closure

Z27 closes the remaining interpretation gap around the Z26 solver-work result.

The physical moving-interface semantics are qualified, but the current research harness is not an implementation from which production speedup can be inferred because it still:

- carries 16 nonlinear unknowns;
- builds a 16 x 16 numerical Jacobian;
- evaluates all 16 Jacobian columns;
- solves a 16-dimensional linear system each Newton iteration.

`upper_n` changes the physical residual structure, not the algebra dimension.

## Direct successor

The research line now transitions from semantic qualification to a production-shaped timestep-manager prototype.

The successor must implement a genuinely variable nonlinear solve dimension while preserving:

- accepted physical state authority;
- exact moving-interface ownership;
- bidirectional one-face motion;
- one physical interface authority;
- physical mass;
- transaction/rollback semantics;
- provider fidelity.

It must then compare adaptive versus full-column reference on identical fixtures and report:

- accepted-state equivalence;
- mass/rollback gates;
- nonlinear work;
- runtime.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z27

BRANCH: `research/f-pe-nlglob14z27-block-normalized-work`

RESEARCH POSTIMAGE BEFORE CLOSEOUT: `f1be15036b686793e7e0d1032dace1a757d6ad19`

QUALIFICATION STATUS: `QUALIFIED_Z27_RESEARCH_HARNESS_NOT_PERFORMANCE_SHAPED`

NEXT SAFE STEP: production-shaped variable-dimension adaptive solve prototype and A/B benchmark against full-column reference.

## Production boundary

No production source/default change.

`LEGACY_NUMERICS` remains production default.
