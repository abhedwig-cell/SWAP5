# F-PE-PZG23-06 — terminal convergence-criterion attribution result

Date: 2026-09-30

Status: QUALIFIED_MULTI_CRITERION_LOCAL_NONLINEAR_BLOCKER

Branch:
`research/f-pe-pzg23-06-terminal-criterion-attribution`

Qualified computational postimage:
`c249db32bf4ef6de678b6983b915eca91404569e`

Canonical baseline:
`integration/f-ci-canonical@c400b02d9956f35c9c20fac09f94b34d5e2ee09f`

Workflow run:
`36765065843`

Job:
`110057047768`

Computation step:
SUCCESS.

The workflow was subsequently cancelled by branch movement/concurrency after the
qualification step had completed. The complete criterion census was emitted by
the successful computation step.

## Question

Which explicit HeadCalc convergence criterion remains violated at terminal
nonlinear exhaustion for the two localized pZg23 interval-B failures?

## Frozen cases

- origin 10: h0=+2 cm, delta=+0.035 cm/day;
- origin 11: h0=+2 cm, delta=+0.050 cm/day.

No production source or numerical policy was changed.

A temporary test copy of HeadCalc emitted dimensionless terminal ratios:

- compartment balance;
- total balance;
- pressure-head change;
- ponding balance where active.

A ratio <=1 satisfies its production criterion.

## Origin 10

Across 14 terminal failed HeadCalc calls:

- compartment ratio >1: 14/14;
- total-balance ratio >1: 14/14;
- head-change ratio >1: 14/14;
- ponding ratio >1: 0/14.

Median terminal ratios:

- compartment: approximately 2.46e8;
- total balance: approximately 4.69e8;
- head change: approximately 6.06e4.

Maximum terminal ratios:

- compartment: approximately 5.67e8;
- total balance: approximately 9.14e8;
- head change: approximately 3.81e7.

## Origin 11

Across 20 terminal failed HeadCalc calls:

- compartment ratio >1: 20/20;
- total-balance ratio >1: 20/20;
- head-change ratio >1: 20/20;
- ponding ratio >1: 0/20.

Median terminal ratios:

- compartment: approximately 2.58e8;
- total balance: approximately 1.79e8;
- head change: approximately 1.66e6.

Maximum terminal ratios:

- compartment: approximately 1.14e9;
- total balance: approximately 2.13e9;
- head change: approximately 6.54e8.

Even the most favorable recorded failed states remain above more than one
criterion. Ponding is inactive in the failing route.

## Hypotheses

H1 — compartment-balance gate alone dominates:

NOT SUPPORTED.

H2 — total-balance gate alone dominates:

NOT SUPPORTED.

H3 — head-change gate alone dominates:

NOT SUPPORTED.

H4 — convergence is multi-criterion:

SUPPORTED.

All failed HeadCalc calls terminate with compartment balance, total balance and
head-change criteria simultaneously unsatisfied.

## Interpretation

This is not a near-threshold numerical-policy problem.

The failing solver states remain orders of magnitude away from the production
criteria. Relaxing one tolerance, increasing MaxIt, or increasing MaxBackTr is
therefore not supported as a bounded repair.

Together with PZG23-01..05, the remaining blocker is classified as a localized
wet positive-forcing nonlinear Richards regime for pZg23.

## Decision

Classification:

`QUALIFIED_PZG23_MULTI_CRITERION_LOCAL_NONLINEAR_BLOCKER`.

No production repair is justified by this research line.

Do not:

- relax mass or solver tolerances;
- widen the 0.20 cm temporal budget;
- increase MaxIt or MaxBackTr;
- reset temporal history;
- treat the issue as worker/OpenMP related.

The scheduler five-profile calibration domain remains blocked by this numerical
solvability hole. Explicit application-owned worker count remains the safe
runtime policy until a separate future solver-development effort addresses this
regime for reasons broader than scheduler calibration.
