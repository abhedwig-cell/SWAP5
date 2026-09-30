# F-PE-PZG23-04 — nonlinear iteration-ceiling falsification result

Date: 2026-09-30

Status: QUALIFIED_ITERATION_CEILING_NOT_SUFFICIENT

Branch:
`research/f-pe-pzg23-04-iteration-ceiling-falsification`

Qualified postimage:
`b50a0f79a3722ce0bb7e389232a827ed50dfe229`

Canonical baseline:
`integration/f-ci-canonical@f133e47f8f7899f3d70db79f9ea63fbb730b2da0`

Workflow run:
`36763456675`

Job:
`110051586010`

Conclusion:
SUCCESS.

## Question

Are the two localized pZg23 interval-B failures caused primarily by the
configured nonlinear iteration ceiling?

## Frozen arms

For origins 10 and 11:

- BASELINE: max_iterations=32, max_backtracking=12;
- ITER64: max_iterations=64, max_backtracking=12.

All other physical and numerical settings remain unchanged.

## Origin 10

BASELINE:

- completed = false;
- solver rejections = 14;
- temporal rejections = 3;
- nonlinear iterations = 496;
- backtracking attempts = 2899.

ITER64:

- completed = false;
- solver rejections = 14;
- temporal rejections = 3;
- nonlinear iterations = 944;
- backtracking attempts = 6197.

Doubling the nonlinear iteration allowance almost doubles nonlinear work while
leaving the rejection structure and completion class unchanged.

## Origin 11

BASELINE:

- completed = false;
- solver rejections = 20;
- temporal rejections = 0;
- nonlinear iterations = 663;
- backtracking attempts = 3698.

ITER64:

- completed = false;
- solver rejections = 41;
- temporal rejections = 5;
- nonlinear iterations = 2915;
- backtracking attempts = 19826.

The larger iteration ceiling does not recover the case and substantially
increases work.

## Decision

Classification:

`ITERATION_CEILING_NOT_SUFFICIENT`.

H1 — nonlinear iteration ceiling is causal:

FALSIFIED as a sufficient explanation.

H2 — increasing the iteration ceiling alone is insufficient:

SUPPORTED.

No hard-mass rejection occurs in either arm.

## Interpretation

The failure is not simply that otherwise-convergent Newton iterations are
prematurely stopped at 32 iterations.

HeadCalc backtracking already explores a geometric damping sequence by factors
of three. With max_backtracking=12 the smallest attempted Newton multiplier is
approximately:

`1 / 3^11 = 5.65e-6`.

Observed mean backtracking work per nonlinear iteration remains about 5.6--6.8,
so there is no direct evidence that the configured backtracking-depth ceiling
is itself the primary limiter.

The next useful discriminator is therefore research-only instrumentation of the
failed HeadCalc solves:

- how often the full backtracking loop is exhausted;
- whether any damped Newton step decreases the residual norm;
- the best residual-ratio reached;
- the terminal Fmax and damping factor.

This can be done with a test-materialized HeadCalc copy without changing
production source.

## Boundaries

Do not:

- admit max_iterations=64;
- increase max_backtracking merely because iteration doubling failed;
- alter temporal budget, hard mass, tolerances or ELAS;
- interpret additional nonlinear work as progress.

No production change follows from PZG23-04.
