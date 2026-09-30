# F-PE-ELASTIC59 — mode-7 defect-certificate cost preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
- F-PE-ELASTIC53 mode-7 defect-indicator candidate;
- F-PE-ELASTIC57 nonmonotonicity-robust controller pattern;
- F-PE-ELASTIC58 physical-budget non-identifiability.

Parent postimage:
`research/f-pe-elastic58-budget-identifiability@627e08d9724c415ec82b9fee843acd0f4c358daf`

Canonical authority:
`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`.

## Question

What is the runtime cost of evaluating the mode-7 defect certificate, and is
that cost small compared with the nonlinear solver-work differences introduced
by ELAS?

## Frozen case

Use ELASTIC55 profile `3030` (`gY30`) with its admitted Staringreeks
retention materialization and generated Ss.

State/forcing:
- h0 = +10 cm;
- delta = +0.05 cm/day;
- dt = 0.015625 day;
- bottom mode 7;
- swkimpl=0;
- explicit fixed-flux top boundary.

Regimes:
- OFF;
- FIXED_1E6;
- GENERATED.

This case is chosen before timing because the ELASTIC55/58 replay shows the
full solve is convergent and the research mode-7 certificate is available in
all three regimes.

## Timed operations

For each regime:

1. `SOLVE_ONLY`
   Recreate the identical request/state and execute one full Reference solve.

2. `INDICATOR_ONLY`
   Starting from one already converged immutable full-solve result, evaluate
   only the research mode-7 temporal indicator with previous right derivative
   fixed to zero.

3. `SOLVE_PLUS_INDICATOR`
   Execute the full solve and, only after convergence, evaluate the indicator.

## Timing protocol

O2 only for timing.

- warmup before measurement;
- 7 replicas;
- identical repeated-call count per operation type and regime;
- use enough repetitions that each reported timing is materially larger than
  timer resolution;
- report median nanoseconds per operation;
- report:
  - indicator / solve ratio;
  - (solve+indicator) / solve ratio;
  - absolute indicator overhead;
  - solver nonlinear iterations, Jacobians, linear solves and backtracking for
    the untimed reference call.

O0/O2 is used only for functional classifications/counters, not timing equality.

## Hypotheses

H1. The indicator cost is small relative to the full nonlinear Reference solve.

H2. The indicator adds exactly one tridiagonal solve and no nonlinear solve.

H3. Active ELAS solver-work reduction in the difficult saturated case is large
enough that solve+indicator with ELAS remains cheaper than solve-only OFF.

H4. FIXED_1E6 and GENERATED certificate cost are similar because the indicator
algorithmic shape is identical.

## Gates

A1. Full solve converges and indicator is available for all three regimes.

A2. Certificate evaluation adds zero nonlinear iterations and exactly one
tridiagonal defect solve.

A3. Timed repeated calls preserve deterministic classifications.

A4. Seven O2 timing replicas complete for each operation/regime.

A5. No production `src/**` change.

## Decision

ELASTIC59 may qualify runtime/cost evidence only.

It does not authorize:
- a production temporal budget;
- production indicator admission;
- controller integration.
