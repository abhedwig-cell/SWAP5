# F-PE-TIMEINT01 closeout — Richards temporal-discretization reconstruction

Date: 2026-09-28

Final status:

`QUALIFIED_BDF2_SUCCESSOR`

Canonical base:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

## Current Reference method

The qualified SWKIMPL=0 Reference route is a semi-implicit first-order one-step method.

For each compartment:

- nonlinear storage theta(h) is implicit at the candidate endpoint;
- pressure-head gradient is endpoint implicit;
- conductivity is lagged from the accepted origin for SWKIMPL=0;
- source/sink and root-sink provider terms are step-frozen from solve start;
- dynamic-top boundary physics is candidate-dependent and piecewise smooth;
- Newton solves the resulting algebraic endpoint problem.

It is therefore not a fully implicit second-order-capable temporal operator merely waiting for a different dt controller.

## Empirical support

TIMEINT01A fixed-step characterization:

- 4/4 smooth cases complete;
- median top-head temporal-order estimate = 0.883;
- B01 cases are close to exact order one;
- bottom-head estimates are also approximately first order.

This supports the source reconstruction.

## Why heuristic controllers plateaued

Legacy NUMBIT-based TimeControl controls algebraic solve difficulty, not temporal truncation error.

TIMEARCH12-17 showed that accepted-state and boundary heuristics can expose large performance headroom, but do not generalize across unseen wet-transition states.

That pattern is consistent with a first-order method lacking a native local truncation-error estimate.

## Candidate assessment

### Step-doubling current method

Rejected as the primary production candidate.

It is robust and useful as an oracle, but full+two-half error control requires too much nonlinear work.

### SDIRK / embedded implicit RK

Retained as a secondary research option.

It has attractive stability and stage-level transition resolution, but normally requires at least two nonlinear implicit stages per accepted step.

### Current-scheme defect estimator

Retained only as a component.

DYNERR01 showed that a smooth endpoint defect is not sufficient across dynamic-top regime-path changes.

### Variable-step BDF2

Selected as the primary successor.

Why:

- second order in smooth regimes when the endpoint operator is made temporally consistent;
- one nonlinear solve per normal accepted step is plausible;
- accepted history maps naturally to the transaction model;
- event/process transitions can trigger first-order restart;
- an embedded lower-order defect estimate may be obtained with one extra linear backsolve instead of another nonlinear solve.

## Critical condition

BDF2 storage with current SWKIMPL=0 lagged conductivity is not presumed second order.

The next workunit must explicitly test operator consistency.

At least these variants must be distinguished:

1. BDF2 storage + current lagged conductivity;
2. BDF2 storage + fully implicit endpoint conductivity/operator;
3. optional second-order coefficient extrapolation only if bounded and defensible.

No BDF2 production claim is allowed until observed order confirms the complete discretization, not only the storage derivative.

## Boundary transition strategy

BDF2 history should be invalidated or downgraded to first order at:

- hard forcing discontinuities;
- process activation/deactivation;
- dynamic-top regime transitions;
- rejected/restarted temporal trajectories;
- any event where the operator is not sufficiently smooth.

After one accepted first-order step, higher-order history may be rebuilt.

## Required successor

`F-PE-TIMEINT02 — BDF2 operator-consistency and cheap error-estimator feasibility`.

TIMEINT02 should remain test-only initially and answer:

- can a true second-order smooth-regime Richards path be obtained;
- what operator treatment is required;
- can the existing Jacobian/factorization support one-backsolve error estimation;
- what is the nonlinear work cost;
- what history/restart semantics are needed.

## Production boundary

No production timestep or Richards-discretization behavior changes in TIMEINT01.

LEGACY_NUMERICS remains default.

AUTO_REFERENCE remains unavailable for production.
