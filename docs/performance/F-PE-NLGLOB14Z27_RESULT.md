# F-PE-NLGLOB14Z27 result — block-size-normalized research-harness work attribution

Date: 2026-09-30

Status:

`QUALIFIED_Z27_RESEARCH_HARNESS_NOT_PERFORMANCE_SHAPED`

Qualification authority:

- workflow run: `36729143355`;
- audit job: `109933766937`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Research postimage before result persistence:

`research/f-pe-nlglob14z27-block-normalized-work@281dd7a1c0e990146b1f844856efbde911425c92`

## Result

The Z22/Z26 research harness classifies:

`FIXED_DIMENSION_RESEARCH_SOLVE`.

Static qualification establishes:

- the state vector remains 16 nodes;
- the residual vector is allocated at length 16;
- the numerical Jacobian is always 16 x 16;
- all 16 Jacobian columns are evaluated every Newton iteration;
- the linear solve therefore remains 16-dimensional;
- `upper_n` changes predictor initialization and residual partitioning, but does not reduce algebra dimension.

Therefore the moving-interface research harness does not yet realize the computational benefit that the physical split is intended to enable.

## Interpretation

This resolves the apparent tension between the strong physical result and the absence of a direct speed number.

Z20-Z26 qualify the moving-interface semantics:

- exact accepted-state ownership;
- bidirectional one-face motion;
- finite local chatter;
- clean mass and rollback behavior;
- no retry/substep burden;
- no chatter-specific Newton spike.

But the research solver still performs a full-column dense numerical-Jacobian solve.

Consequently Z26 Newton counts characterize local convergence behavior, not the runtime gain of a real adaptive solve.

## Qualified claim boundary

Qualified:

- current research harness is fixed-dimension;
- smaller `upper_n` does not reduce Jacobian or linear-system dimension;
- speedup from reduced active block has not yet been measured.

Not qualified:

- expected magnitude of production speedup;
- production variable-dimension solver;
- end-to-end runtime gain;
- production admission.

## Consequence

The next step should stop treating the research harness as a performance prototype.

A production-shaped successor must:

1. retain the already-qualified accepted-state moving-interface semantics;
2. materialize a genuinely variable nonlinear solve dimension;
3. preserve exact interface mass accounting;
4. compare that adaptive solve directly with a full-column reference on identical trajectories;
5. report both physical equivalence and runtime/work reduction.

This is the appropriate bridge from research semantics to a candidate SWAP Heritage timestep manager.

## Production boundary

Research only.

No production source/default change.

`LEGACY_NUMERICS` remains production default.
