# F-PE-TIMEINT01 — modern integrator option assessment

Date: 2026-09-28

Canonical authority:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

## Candidate A — current first-order scheme + full step doubling

### Mechanism

For requested dt:

- solve one full interval;
- solve two half intervals;
- compare endpoints;
- accept the refined route or use the difference as local error estimate.

### Strengths

- directly measures temporal path sensitivity;
- naturally exposes dynamic-top regime-path changes;
- requires little mathematical change to the current one-step solver;
- transaction semantics already support full/half rollback.

### Cost

Nominally three nonlinear solves per assessed interval.

Recent EMBEDSTEP work already demonstrated the practical problem: once two-half refinement is invoked often enough for robustness, most of the large-step performance gain disappears.

### Assessment

Useful as validation/oracle machinery.

Poor default production integrator candidate unless invoked very rarely.

Status:

`RETAIN_AS_ORACLE_NOT_PRIMARY_INTEGRATOR`.

## Candidate B — variable-step BDF2 with first-order fallback

### Smooth-regime formulation

For constant dt, a conservative BDF2 storage derivative would use:

`(3 M^{n+1} - 4 M^n + M^{n-1}) / (2 dt)`.

For variable step sizes, coefficients must depend on the current/previous step ratio.

Flux/source operator should be evaluated consistently at the new endpoint for genuine second-order behavior.

### Critical qualification issue

Simply replacing the current first-order storage difference by BDF2 while keeping SWKIMPL=0 conductivity frozen at time n would not establish a clean second-order Richards discretization.

The lagged conductivity and other frozen state-dependent terms can retain first-order error.

A serious BDF2 candidate therefore needs one of:

1. fully implicit endpoint conductivity/operator evaluation;
2. a separately qualified second-order extrapolation of lagged coefficients;
3. proof that the lagged terms are not order limiting in the intended profile.

Option 1 is the cleanest mathematically, but intersects SWKIMPL=1 correctness/qualification.

### Error estimate

BDF2 has a major architectural advantage.

After one converged BDF2 endpoint, a lower-order residual/defect can be evaluated at the same candidate.

A local error correction can potentially be estimated using:

- the already assembled/factorized endpoint Jacobian;
- one additional tridiagonal backsolve;
- no additional nonlinear solve.

This resembles the existing temporal-defect architecture but would compare two time-discretization formulas sharing the same endpoint operator, rather than trying to infer dynamic-top path error from endpoint history alone.

### Boundary transitions

BDF2 assumes smooth enough history.

At:

- forcing discontinuities;
- dynamic-top regime transitions;
- process activation/deactivation;
- rejected/restarted trajectories;

the method should fall back to first order and rebuild history.

A transition does not invalidate BDF2 as a general integrator, but transition detection and restart semantics are part of the algorithm.

### Transaction state

Committed history must include at minimum:

- previous accepted physical state needed by the BDF formula;
- previous accepted dt;
- history-valid flag/order state.

History advances only on commit.

### Expected cost

Normal smooth step:

- one nonlinear solve;
- possibly one extra linear backsolve for error estimation.

Transition/bootstrap step:

- first-order solve;
- history restart.

### Assessment

Best current candidate for a production-oriented modern integrator study.

Status:

`PRIMARY_SUCCESSOR_CANDIDATE`.

## Candidate C — SDIRK / embedded implicit Runge-Kutta

### Mechanism

A second-order singly diagonally implicit RK method can provide:

- higher-order implicit time integration;
- embedded lower-order estimate in some pairs;
- good stability for stiff systems.

### Cost

Typically at least two implicit stages.

Even with shared diagonal coefficient and reusable matrix structure, each stage generally needs its own nonlinear solution because hydraulic constitutive state changes.

### Dynamic-top benefit

Stage values can in principle resolve boundary evolution inside the interval better than a pure endpoint multistep formula.

This is attractive near regime transitions.

### Practical concern

Reference runtime is dominated by the nonlinear physical solve.

Doubling implicit stages on every accepted step is therefore a high bar.

A SDIRK candidate would need substantially larger accepted intervals to offset its structural cost.

### Assessment

Scientifically strong fallback candidate if BDF2 fails on transition robustness.

Not the first performance candidate.

Status:

`SECONDARY_RESEARCH_CANDIDATE`.

## Candidate D — cheap defect estimator around the current first-order scheme

### Mechanism

Retain the current physical step and estimate time error from:

- derivative history;
- residual defect;
- one extra linear solve.

### Evidence

The existing fixed-flux temporal indicator proves this can work in a bounded smooth profile.

DYNERR01 showed the endpoint defect does not generalize to dynamic top:

- rank correlation too weak;
- severe false-safe at a flux -> head transition.

### Assessment

The concept remains useful inside smooth regimes.

It is not sufficient as the complete dynamic-top temporal controller unless paired with a stronger transition treatment.

Status:

`COMPONENT_NOT_STANDALONE_SUCCESSOR`.

## Why BDF2 ranks first

The performance target matters.

The ideal next method should provide:

- higher temporal accuracy per nonlinear solve;
- a local error signal;
- no routine second full nonlinear solve;
- clean transaction history;
- exact event restart semantics.

BDF2 is the only assessed option that plausibly satisfies all four simultaneously.

## Main risk

A BDF2 wrapper around the current SWKIMPL=0 operator is not enough.

The next workunit must first determine the minimum endpoint-operator change needed to obtain actual second-order convergence.

That question precedes controller calibration.

## Recommended successor

`F-PE-TIMEINT02 — BDF2 operator-consistency and error-estimator feasibility`.

TIMEINT02 should be test-only first.

It should compare at least:

1. BDF2 storage + current lagged K;
2. BDF2 storage + fully implicit endpoint K;
3. optionally second-order extrapolated K if mathematically and physically bounded.

Use smooth fixed-regime cases first.

Primary outputs:

- observed temporal convergence order;
- nonlinear work per unit simulated time;
- stability;
- one-linear-solve embedded error-estimator correlation;
- transition fallback design.

No dynamic-top production admission should occur until the smooth-regime method itself demonstrates the intended order.
