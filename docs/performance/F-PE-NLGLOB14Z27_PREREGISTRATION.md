# F-PE-NLGLOB14Z27 preregistration — block-size-normalized research-harness work attribution

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority: `integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Parent: `F-PE-NLGLOB14Z26` at `6307cdb871f2f7a2a7b5ef65d520971168976c6e`.

## Purpose

Determine whether the current Z22/Z26 research harness actually realizes computational savings from the moving-interface split, or only changes the physical residual semantics while retaining a fixed full-column nonlinear algebra dimension.

## Frozen questions

1. What is the dimension of the Newton unknown vector used by `solve_interval`?
2. What is the dimension of the numerical Jacobian built per Newton iteration?
3. Does `upper_n` reduce the linear-system dimension, or only alter residual construction and predictor initialization?
4. Can Z26 Newton-iteration counts therefore be interpreted as a direct estimate of production speedup from reduced active block size?

## Frozen classifications

- `VARIABLE_DIMENSION_RESEARCH_SOLVE`: algebra dimension follows `upper_n`.
- `FIXED_DIMENSION_RESEARCH_SOLVE`: full 16-variable Jacobian/solve remains active regardless of `upper_n`.
- `AMBIGUOUS_DIMENSION`: static code does not establish the dimension.

If fixed dimension is established, the aggregate is:

`QUALIFIED_Z27_RESEARCH_HARNESS_NOT_PERFORMANCE_SHAPED`.

## Consequence

A fixed-dimension result means the physical moving-interface semantics are qualified, but a speed claim requires a production-shaped implementation where the nonlinear algebra dimension actually follows the active block.

Do not infer runtime speedup from Z26 iteration counts alone.

## Production boundary

Research audit only. No production source/default change.
