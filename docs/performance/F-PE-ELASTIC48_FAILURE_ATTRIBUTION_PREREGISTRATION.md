# F-PE-ELASTIC48 — smallest-duration failure attribution preregistration

Date: 2026-09-29

Status: PREREGISTERED_OBSERVATION_ONLY

Parent:
`F-PE-ELASTIC47 — QUALIFIED_NEGATIVE_TIMESTEP_INTERACTION_RESULT`

Parent postimage:
`research/f-pe-elastic47-timestep-interaction@d6d5514142eabb426b83944c1716c06ee144a287`

## Question

Why do the difficult saturated perturbations still fail at the smallest
ELASTIC47 interval, `dt = 0.015625 day`, even though ELAS can reduce nonlinear
work substantially?

## Frozen attribution bank

Use the same real profile, generated prior, variable grid, hydraulic fixture,
solver, tolerances and transaction policy as ELASTIC47.

Cases:
- `h0 = 2 cm`, delta `+0.05` and `-0.05 cm/day`;
- `h0 = 10 cm`, delta `+0.05` and `-0.05 cm/day`;
- regimes `OFF`, `FIXED_1E6`, `GENERATED`;
- fixed `dt = 0.015625 day`.

Total: 12 cases.

## Required diagnostics

Run the admitted serialized Reference backend directly from a captured
checkpoint and record:
- kernel result status and completed flag;
- transaction calls;
- attempts and retries;
- solver rejections;
- temporal rejections;
- temporal-certificate-unavailable rejections;
- mass rejections;
- admission rejections;
- checkpoint rejections;
- nonlinear iterations;
- internal retries;
- HeadCalc calls;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- backend solver-executed flag and route;
- candidate readiness;
- mass completeness/residual when available.

## Hypotheses

H1. The failure is dominated by solver rejection before mass acceptance.

H2. The failure is not primarily a full-half temporal rejection.

H3. ELAS changes the amount of solver work but not the dominant rejection
classification.

## Gates

A1. All 12 cases execute.
A2. O0/O2 diagnostic classifications are identical.
A3. No source or numerical-policy change.
A4. Attribution is based on existing diagnostics only.
A5. Zero `src/**` changes.

## Decision

If one rejection class dominates consistently, close ELASTIC48 with that
attribution and route the next workunit to that layer. Do not open a repair
inside ELASTIC48.
