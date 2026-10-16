# F-PE-REPRO02 — difficult-origin exact participant admissibility

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC`

Parent:
`F-PE-APPROX04`

## Trigger

APPROX04 P1B established that the exact FGC44 participant has no common nonzero displacement frontier across the six difficult PROFILE06 origins.

Five of six cases rejected even +/-0.001 cm corrector displacements.

The local exact q(h) response itself is smooth over much larger windows, so the limiting mechanism is transaction admissibility rather than constitutive response geometry.

## Purpose

Identify which exact acceptance mechanism rejects difficult-origin nonzero corrector trials.

This is a numerical/transaction diagnosis.

Do not optimize performance.

Do not introduce a surrogate.

## Primary comparison

For each difficult origin compare:

- zero displacement exact trial;
- -0.001 cm exact trial;
- +0.001 cm exact trial.

Include B01-mid +0.001 cm as the known small nonzero PASS control.

## Required diagnostics

After every trial attempt, including failure, report from the serialized Reference backend:

### Solver
- solver executed;
- solver status;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- internal retries;
- constitutive evaluations;
- equation residual availability/value.

### Temporal acceptance
- temporal indicator status;
- indicator availability;
- normalized indicator;
- head-inf bound;
- active model temporal budget.

### Mass/accounting
- mass completeness where exposed;
- compartment/total balance residual authority where exposed;
- bottom exchange;
- terminal bottom flux.

### Transaction outcome
- participant status;
- candidate validity/publication readiness where queryable.

## Phase R1

Use only observation/test bridge instrumentation.

No `src/**` changes.

Fresh process per point.

Run enough repetitions to establish that each pass/fail signature is deterministic for the tested displacement.

## Decision tree

If failed trials show nonconverged/retry-advised solver status:
- localize to nonlinear solve/path sensitivity.

If solver converges but temporal acceptance rejects:
- localize to temporal certificate policy.

If solver and temporal certificate pass but transaction still rejects:
- inspect mass/whole-window acceptance next.

If signatures differ by material/regime:
- preserve that regime split rather than forcing one explanation.

## Closure

REPRO02 closes when the first authoritative rejection mechanism is identified well enough to preregister either:

- a numerical-policy study;
- a defect repair;
- or a justified no-change conclusion.
