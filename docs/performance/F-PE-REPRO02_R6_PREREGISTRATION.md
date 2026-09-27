# F-PE-REPRO02 R6 — optional-direction physical-solve invariance

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

R1-R5 excluded scalar solver limits, minimum step, legacy-context binding and nominally inactive boundary carriers.

A structural route difference remains:

- serialized FGC44 corrector config sets accepted-trajectory direction requested = false and therefore executes plain `solver%solve`;
- P0/R4/R5 use `solve_with_accepted_step_direction`, which prepares reusable tridiagonal-factorization scratch before calling the same physical solver.

The optional directional capability is post-physical diagnostic functionality and must not alter whether the physical solve converges.

## Question

Does requesting the optional accepted-step direction change physical mode-5 convergence for the difficult-origin +/-0.001 cm cases?

## Arms

Identical solve request, providers, state, boundary and numerical controls:

- PLAIN: call `solver%solve(request,...)`;
- DIRECTION: call `solve_with_accepted_step_direction(...)` with zero incoming direction and direct bottom-head derivative 1.

Use 48 nonlinear iterations, 16 backtracking and min step 1e-10 day.

## Cases

Six difficult PROFILE06 origins.

Offsets:

- -0.001 cm;
- 0;
- +0.001 cm.

Three repetitions per point.

## Decision

If PLAIN reproduces participant retry-advised failures while DIRECTION converges, the physical Reference solve violates optional-direction invariance.

That is a solver/workspace defect candidate and requires a separate minimal repair workunit before further APPROX04 work.

If both arms behave identically, continue request/state/provider comparison.
