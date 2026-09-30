# F-PE-ELASTIC58A — refined-oracle solvability attribution preregistration

Date: 2026-09-30

Status: PREREGISTERED_OBSERVATION_ONLY

Parent:
`F-PE-ELASTIC58 — QUALIFICATION_BLOCKED_BY_REFINED_ORACLE_SOLVABILITY`

Parent postimage:
`research/f-pe-elastic58-physical-budget@9fe6a38363e177caf679c776999b1497e7dd4953`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Question

Why did all 97 C-SAFE accepted ELASTIC58 cases fail the 32-equal-substep
Reference oracle?

## Frozen replay

Preserve exactly:
- ELASTIC58 selected profiles 11020, 8120, 4015, 3011;
- frozen alpha 0.17320259355765216;
- H_budget 0.01 cm;
- C-SAFE selection;
- materialization, solver, forcing, tolerances and mode-7 physics;
- 32 equal oracle substeps.

No budget, alpha or physical gate changes.

## Required diagnostics

For every C-SAFE accepted case record:
- accepted dt;
- oracle substep dt;
- first failing substep index;
- solver status at failure;
- nonlinear iterations;
- backtracking attempts;
- Jacobian builds;
- linear solves;
- HeadCalc calls;
- internal retries if exposed;
- last successfully completed substep index;
- terminal head range after last successful substep.

Also classify:
- FIRST_SUBSTEP_FAILURE;
- LATE_CHAIN_FAILURE.

## Additional bounded discriminator

For attribution only, independently test the same accepted initial state at
single-step durations:

- dt/2;
- dt/4;
- dt/8;
- dt/16;
- dt/32.

Record convergence only.

This discriminator does not replace the 32-substep oracle and cannot qualify
the physical budget.

## Hypotheses

H1. Most oracle failures occur on substep 1 because dt/32 falls into the known
small-dt solver-convergence window.

H2. If H1 is true, the blocker is oracle construction/solver solvability rather
than accumulated trajectory drift.

H3. The failure pattern is largely independent of ELAS regime in unsaturated
states.

## Gates

A1. Reproduce exactly the 97 ELASTIC58 accepted cases.

A2. Every accepted case receives a failure index/status.

A3. O0/O2 diagnostic classification agrees.

A4. No physical/numerical policy change.

A5. Zero src/** production changes.

## Decision

If failures are predominantly first-substep small-dt failures, route the next
work to a separately qualified refined-oracle construction.

No H_budget claim is made in ELASTIC58A.
