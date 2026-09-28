# F-RETC01 — compatibility kernel contract

Status: preregistered implementation contract  
Canonical authority observed before write: `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`

## Purpose

Define the smallest executable kernel that may legitimately be called a RETC Version 1.0 reconstruction. This contract is source-derived and intentionally excludes modern improvements.

## Required historical semantics

### Numeric model

- double-precision real arithmetic corresponding to the source's `IMPLICIT REAL*8`;
- historical seven-parameter ordering: residual water content, saturated water content, alpha, n, m, pore-connectivity exponent, saturated conductivity;
- fixed/fitted parameter selection through the historical index semantics;
- model restrictions must be applied before optimization exactly as selected by MTYPE.

### Objective

For every active observation:

`r_i = W_i (Y_i - F_i)`

and

`SSQ = sum_i r_i^2`.

Therefore compatibility mode must not reinterpret `W_i` as a conventional least-squares weight whose square root enters the residual.

K/D log transformation is controlled by METHOD and occurs internally before optimization.

### Numerical derivatives

For active parameter `theta_j`:

`theta_j^+ = (1 + DERL) theta_j`

with

`DERL = 0.002`.

The historical one-sided relative perturbation is part of the compatibility contract. Zero and near-zero special cases must follow source control flow rather than a generic finite-difference fallback.

### Scaled normal equations

The source forms weighted finite-difference columns, a moment matrix, diagonal scales `E_i = sqrt(D_ii)`, and solves a scaled system. Compatibility mode must preserve this scaling and the source matrix-inversion semantics closely enough to reproduce official cases.

### Marquardt control

Initial damping:

`GA = 0.05`.

At each outer iteration the source first applies:

`GA = 0.05 GA`.

The scaled moment-matrix diagonal is then augmented by `GA`.

A candidate correction starts with `STEP = 1`. Historical control flow may halve STEP and may multiply GA by 20 when the objective/gradient geometry is unacceptable. These branches are observable algorithm semantics, not implementation details to replace casually.

### Convergence

Default:

`STOPCR = 0.00010`.

For every active parameter the source evaluates the relative correction:

`abs(P_i STEP / E_i) / (1e-20 + abs(theta_i))`.

Termination requires the historical all-parameter test to pass. MIT remains an independent iteration ceiling.

### Historical safeguards

Compatibility mode must preserve source-defined special handling, including:

- rejection/redirect of parameter proposals that cross sign through zero;
- residual-water-content handling after early iterations when its fitted value collapses toward zero;
- pore-connectivity exponent handling near zero;
- model-family restrictions on n and m;
- invalid-model return/status behaviour.

These safeguards must be tested explicitly because a bounded modern optimizer will generally behave differently.

## Architecture boundary

The compatibility implementation must live under research tooling and must not be imported by production SWAP solver code.

A later modern fitter may share independently verified forward hydraulic equations, data structures and test fixtures. It must not silently share optimizer behaviour under a single ambiguous 'RETC' mode.

Recommended naming:

- `retc_v10_compat`: literal historical reconstruction;
- `hydraulic_fit`: later modern estimator;
- explicit adapter: fitted RETC parameter set -> selected SWAP hydraulic model.

## Admission gates

C0. Forward equations reproduce an official direct example at printed precision.

C1. A retention-only inverse example reproduces final fitted parameters, objective and iteration count or has a documented compiler/rounding explanation.

C2. A simultaneous retention plus conductivity example reproduces the same observables.

C3. At least one edge case exercises a historical safeguard.

C4. Independent tests demonstrate that changing to conventional sqrt-weight semantics changes the result when non-unit weights are used. This prevents accidental modernization.

C5. No production SWAP source file is changed.

Passing C0-C5 qualifies the compatibility kernel for research use only. It does not admit a modern estimator or a SWAP parameter-generation workflow.
