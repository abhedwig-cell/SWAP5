# F-PE-ELASTIC60 — persistent half1 failure postmortem result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic60-half1-postmortem`

Qualified postimage:
`cdb965e4df8ba7f7484ed64287021c364ae706f8`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36680085130`

Job:
`109773405817`

Conclusion:
SUCCESS.

## Question

What numerical mechanism keeps the ELASTIC59 half1 verification solve
nonconvergent through max_iterations=128?

## Frozen cases

Exactly the six ELASTIC59 cases:
- profile 8016;
- h0=-20 cm;
- delta=+0.035 and +0.05 cm/day;
- OFF, FIXED_1E6, GENERATED;
- accepted full-step dt=0.0009765625 day;
- half1 dt=0.00048828125 day.

Oracle max_iterations:
16, 32, 64, 128.

All other settings were unchanged.

## Primary result

The terminal postmortem state is invariant as the iteration budget increases.

For delta=+0.035, every regime and every maxit arm ends with:

- half1 status = retry advised;
- max compartment residual:
  `8.379963389870682e-13 cm/day`;
- total residual sum:
  `4.169331546677313e-12 cm/day`;
- residual L2:
  `1.757283098275243e-12 cm/day`;
- max-residual node: 13;
- no alternative linear solver;
- one internal retry marker;
- zero saturated nodes.

For delta=+0.05:

- max compartment residual:
  `8.366640713575180e-13 cm/day`;
- total residual sum:
  `1.056710274838224e-12 cm/day`;
- residual L2:
  `1.513959111093547e-12 cm/day`;
- max-residual node: 13;
- same route and regime-independent behavior.

The max compartment residual is below the configured compartment criterion
`1e-12` in both forcing cases.

The total residual sum remains above the configured total-balance criterion
`1e-12`:
- by about 4.17x for delta=+0.035;
- by about 1.057x for delta=+0.05.

The HeadCalc convergence contract explicitly tests
`abs(sum(residual)) > CritDevBalTot`
after the per-compartment checks.

This makes the total-balance gate the leading mechanistic limiter candidate.

## Iteration-budget behavior

Increasing max_iterations does not improve the terminal residual snapshot.

Residual improvement ratio from maxit16 to maxit128:

`1.0`

for all six cases.

Backtracking instead scales upward with the available iteration budget.

At maxit128:
- delta=+0.035: 494 backtracking attempts, about 3.86 per nonlinear iteration;
- delta=+0.05: 493 attempts, about 3.85 per iteration.

Jacobian builds and linear solves track nonlinear iterations exactly.

There are:
- no alternative-solver calls;
- no regime-dependent differences;
- no saturation transition.

Thus the path is repeated nonlinear/backtracking work around an unchanged
terminal residual floor.

## Important snapshot caveat

The solve result candidate state on the retry-advised route is not a qualified
accepted iterate and may reflect rollback/reset semantics.

Therefore the observed
`max_last_dh`
quantity from candidate-state minus workspace old-head is not used as a
standalone convergence attribution.

The residual diagnostics and solver counters are the controlling evidence.

## Regime attribution

OFF, FIXED_1E6 and GENERATED are bit-identical in the postmortem diagnostics.

This is expected for the h0=-20 cm unsaturated state and confirms that the
coverage gap is not caused by active saturated elastic storage.

## Hypothesis outcome

H1, residual/backtracking stagnation rather than insufficient iteration count:
SUPPORTED.

H2, regime independence:
SUPPORTED.

H3, no alternative-solver explanation:
SUPPORTED.

A specific total-balance criterion as the decisive rejection mechanism:
STRONGLY INDICATED but not yet causally proven, because ELASTIC60 did not alter
the criterion.

## Decision

Classification:

`QUALIFIED_HALF1_TOTAL_BALANCE_FLOOR_CANDIDATE`.

No production change is authorized.

The next bounded workunit should perform a verification-only sensitivity of
`total_balance_tolerance` while keeping:
- compartment balance tolerance fixed at 1e-12;
- head tolerances fixed;
- physical model fixed;
- production full solve unchanged.

The sensitivity should determine whether crossing the observed total residual
floor restores half1 convergence and paired-oracle coverage without violating
the external head/theta error envelope.
