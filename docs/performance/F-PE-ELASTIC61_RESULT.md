# F-PE-ELASTIC61 — verification-only total-balance sensitivity result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic61-total-balance-sensitivity`

Qualified postimage:
`9d8205397b75f6792d980c1d3b65659fc22207b4`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36680481886`

Job:
`109774618408`

Conclusion:
SUCCESS.

## Question

Is the persistent half1 verification failure in the six ELASTIC59/60 cases
causally controlled by the solver-local total-balance convergence criterion?

## Frozen sensitivity

Exactly the six profile-8016 cases were replayed:

- h0 = -20 cm;
- delta = +0.035 and +0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- full-step dt = 0.0009765625 day;
- half-step dt = 0.00048828125 day.

The production-shaped full solve remained unchanged.

Only the half1/half2
`total_balance_tolerance`
was varied:

- 1.0e-12;
- 1.1e-12;
- 2.0e-12;
- 5.0e-12;
- 1.0e-11.

The compartment balance tolerance remained exactly 1e-12.

## Preregistered causal prediction

ELASTIC60 observed half1 terminal total residual sums of approximately:

- delta +0.035: 4.1693e-12 cm/day;
- delta +0.05: 1.0567e-12 cm/day.

Therefore ELASTIC61 preregistered:

- +0.05 should recover at 1.1e-12 or above;
- +0.035 should first recover at 5e-12.

That prediction was made before the sensitivity run.

## Primary result

The preregistered recovery thresholds are reproduced exactly in every regime.

### delta = +0.035 cm/day

OFF, FIXED_1E6 and GENERATED all show:

- 1.0e-12: half1 fails;
- 1.1e-12: half1 fails;
- 2.0e-12: half1 fails;
- 5.0e-12: half1 converges and half2 converges;
- 1.0e-11: half1 converges and half2 converges.

First half1 recovery:

`5.0e-12`.

At the recovered half1 solve:

- nonlinear iterations drop from 16 to 7;
- backtracking drops from 46 to 10;
- max compartment residual remains
  `8.379963389870682e-13`;
- total residual sum remains
  `4.169331546677313e-12`.

Thus convergence changes solely because the total-balance criterion is allowed
to exceed the already-stagnated total residual floor.

### delta = +0.05 cm/day

OFF, FIXED_1E6 and GENERATED all show:

- 1.0e-12: half1 fails;
- 1.1e-12: half1 converges;
- 2.0e-12: half1 converges;
- 5.0e-12: half1 converges;
- 1.0e-11: half1 converges.

First half1 recovery:

`1.1e-12`.

Again this matches the preregistered expectation from the observed
`1.056710274838224e-12`
total residual floor.

At the recovered half1 solve:

- nonlinear iterations drop from 16 to 6;
- backtracking drops from 45 to 7;
- max compartment residual remains below 1e-12.

## Half2 behavior

For delta +0.035:

- once half1 first recovers at 5e-12, half2 also converges.

For delta +0.05:

- half1 already recovers at 1.1e-12;
- half2 still fails at 1.1e-12 and 2e-12;
- both half1 and half2 converge at 5e-12 and 1e-11.

Therefore half2 has its own total-balance convergence floor above 2e-12 in the
+0.05 cases.

The complete paired oracle is recovered at 5e-12 for all six physical cases.

## Physical-envelope result

Across all recovered paired observations:

- paired observations: 12;
- head-limit failures: 0;
- water-content-limit failures: 0;
- frozen global-envelope failures: 0.

Every recovered pair satisfies:

`H_INF <= 0.01 cm`;

`DTHETA_INF <= 1e-5`;

and

`H_INF <= 0.17320259355765216 * Binf`.

The research sensitivity therefore recovers oracle coverage without producing
a physical-error violation in the observed pairs.

## Causal attribution

ELASTIC60 identified a stable total residual floor above
`CritDevBalTot=1e-12`.

ELASTIC61 changes only the verification half-step total-balance convergence
criterion.

The recovery thresholds then occur exactly where the preregistered residual
floor predicts.

This establishes the solver-local total-balance criterion as the causal blocker
for the six missing paired oracles.

The failure is not caused by:
- insufficient max_iterations;
- ELAS regime;
- compartment residual excess;
- alternative linear solver;
- saturation transition.

## Important policy distinction

The varied quantity is a solver-local nonlinear convergence criterion in
cm/day.

It is not:
- the canonical transaction mass ledger;
- a physical accepted-interval water-balance tolerance;
- the ELASTIC54/55 temporal error envelope.

No hard transaction mass acceptance was relaxed in ELASTIC61.

## Hypothesis outcome

Total-balance convergence criterion is causal:
SUPPORTED.

Preregistered threshold pattern:
SUPPORTED exactly.

Regime independence:
SUPPORTED.

Recovered paired physical envelope:
SUPPORTED in all observed recovered pairs.

## Decision

Classification:

`QUALIFIED_VERIFICATION_TOTAL_BALANCE_FLOOR_CAUSALITY`.

No production solver-tolerance change is authorized.

The next bounded question is whether the strict 1e-12 total-balance convergence
criterion should be represented by a numerically justified floor for this
explicit Reference solve, distinct from hard physical mass acceptance.

Any such floor must be independently derived from floating-point/representation
scale and validated broadly before production consideration.
