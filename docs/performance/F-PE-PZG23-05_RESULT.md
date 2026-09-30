# F-PE-PZG23-05 — backtracking descent instrumentation result

Date: 2026-09-30

Status: QUALIFIED_BACKTRACKING_DEPTH_NOT_PRIMARY

Branch:
`research/f-pe-pzg23-05-backtracking-descent-instrumentation`

Qualified postimage:
`c21a46126d5797407a93ebb00ed5da45e8249d40`

Canonical baseline:
`integration/f-ci-canonical@c400b02d9956f35c9c20fac09f94b34d5e2ee09f`

Workflow run:
`36764521802`

Job:
`110055202048`

Conclusion:
SUCCESS.

## Question

Are the two localized pZg23 interval-B failures primarily caused by exhausting
the configured 12-step HeadCalc backtracking search, or by a Newton direction
that remains non-descent even at very small damping?

## Frozen cases

- origin 10: h0=+2 cm, delta=+0.035 cm/day;
- origin 11: h0=+2 cm, delta=+0.050 cm/day.

Production policy and numerical settings were unchanged.

Only a test-materialized copy of HeadCalc was instrumented.

Production `src/**` remained unchanged.

## Origin 10

Across the interval-B transaction:

- HeadCalc calls: 20;
- failed HeadCalc calls: 14;
- converged HeadCalc calls: 6;
- total backtracking-loop exhaustions inside failed calls: 47;
- failed calls whose terminal nonlinear iteration exhausted all 12
  backtracking attempts: 1;
- terminal non-descent-at-full-depth cases: 1;
- terminal descent-at-full-depth cases: 0;
- minimum attempted damping factor: 5.645029269476763e-6.

The failed HeadCalc calls contain many nonlinear iterations that do find a
residual-reducing damped Newton step.

## Origin 11

Across the interval-B transaction:

- HeadCalc calls: 22;
- failed HeadCalc calls: 20;
- converged HeadCalc calls: 2;
- total backtracking-loop exhaustions inside failed calls: 81;
- failed calls whose terminal nonlinear iteration exhausted all 12
  backtracking attempts: 2;
- terminal non-descent-at-full-depth cases: 2;
- terminal descent-at-full-depth cases: 0;
- minimum attempted damping factor: 5.645029269476763e-6.

Again, most failed HeadCalc calls do not terminate because their final
nonlinear iteration exhausts the backtracking loop.

Several failed calls show 30--32 accepted residual-reducing Newton updates and
still fail the final convergence test.

## Hypotheses

H1 — repeated backtracking-search exhaustion dominates:

FALSIFIED as the primary terminal mechanism.

Full backtracking exhaustion occurs internally, but only 1/14 and 2/20 failed
HeadCalc calls terminate on an exhausted final nonlinear iteration.

H2 — Newton direction is broadly non-descent:

FALSIFIED as the general mechanism.

Most nonlinear iterations find a damped step with lower residual norm.

H3 — increasing backtracking depth is a plausible first repair:

NOT SUPPORTED.

The existing search already reaches damping as small as approximately
`1/3^11`, while most failed solver calls terminate for a different reason.

## Interpretation

Together with PZG23-04, the remaining mechanism is now narrower:

- increasing nonlinear iteration count alone is insufficient;
- increasing backtracking depth is not supported as the first repair target;
- residual-reducing Newton progress is often present;
- yet the final convergence gate is not reached.

The next useful diagnostic is therefore direct attribution of the terminal
convergence criteria:

1. maximum compartment balance residual;
2. total balance residual;
3. maximum normalized pressure-head change;
4. ponding balance criterion where active.

## Decision

Classification:

`QUALIFIED_PZG23_CONVERGENCE_CRITERION_CONFLICT_REMAINS`.

No production solver change follows from PZG23-05.
