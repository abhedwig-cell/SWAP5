# F-PE-NLGLOB14Z28 preregistration — variable-dimension timestep-manager bootstrap

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Parent authority:

- Z20-Z22: exact accepted-state moving-interface semantics, bidirectional one-face motion and finite chatter qualified on fine O05 fixtures;
- Z24: moving-interface chatter is internal to SWAP under the current groundwater-coupling surface;
- Z25: chatter causes no timestep retry/substep burden;
- Z26: chatter is not a Newton-iteration work spike;
- Z27: the research harness is fixed-dimension and therefore not a performance prototype.

## Purpose

Open the software transition from semantic research to a production-shaped SWAP Heritage timestep manager.

Z28 is a bootstrap workunit. Its purpose is to prove that the existing production reference-solver infrastructure can execute with a genuinely variable algebra dimension owned by `active_nodes`, and to establish the exact manager contract needed to bind the qualified moving-interface semantics onto that infrastructure.

Z28 does not yet claim full physical equivalence of the moving-interface solver.

## Existing production primitives to reuse

Current canonical already provides:

- `reference_richards_workspace_t%active_nodes`;
- `ensure_reference_workspace_shape(workspace, active_nodes)`;
- workspace arrays allocated at exactly `active_nodes`;
- `reference_tridag(n,...)` with explicit solve dimension `n`;
- `reference_band_solve` deriving `n=size(b)`;
- typed solver diagnostics for nonlinear iterations, Jacobian builds, linear solves and constitutive evaluations.

Z28 must reuse these primitives rather than introducing a second linear-solver stack.

## Frozen manager boundary

Define a research-only manager contract with two distinct authorities.

### Full accepted state

The full SWAP column remains the only physical accepted-state authority.

It retains all nodes, water contents, pressure heads, ponding and provenance.

### Active nonlinear solve view

The manager may derive an active contiguous upper solve view from the accepted state.

The active view has:

- `active_nodes = upper_n`;
- full-column origin identity;
- interface face identity;
- one saturated lower-tail descriptor;
- exact interface exchange accumulator;
- no independent accepted-state authority.

The active solve view is reconstructible scratch state.

## Z28 bootstrap questions

Q1. Can the production workspace be repeatedly reshaped across at least the qualified dimensions 11, 12 and 13 without stale-state leakage?

Q2. Does the reference TRIDAG path execute with exactly the supplied `n`, rather than full-column dimension?

Q3. Can a manager transition `12 -> 11 -> 12 -> 13 -> 12` while preserving explicit full-state ownership outside the active scratch view?

Q4. Can solver diagnostics prove reduced algebra work when `active_nodes < 16`?

Q5. Can the manager contract prevent the reduced workspace from becoming a second physical-state authority?

## Frozen qualification fixture

Use a deterministic algebra/bootstrap fixture rather than the full NLGLOB physics trajectory.

Required active-dimension sequence:

`12 -> 11 -> 12 -> 13 -> 12`.

For each dimension:

1. call the production workspace-shape authority;
2. populate deterministic tridiagonal coefficients of that dimension;
3. solve through the production `reference_tridag`;
4. verify residual to a strict algebraic bound;
5. poison or fingerprint unused/previous storage where applicable;
6. resize to the next dimension;
7. prove no stale value is read as active data.

Also run a fixed full-dimension `n=16` control.

## Required work diagnostics

Record per solve:

- `n`;
- allocated workspace active_nodes;
- coefficient count;
- forward-elimination row count;
- back-substitution row count;
- solution residual;
- workspace payload bytes.

For the tridiagonal algorithm, define deterministic structural work units:

`W(n) = n + (n-1)`

representing n forward rows plus n-1 back-substitution rows.

This is not wall-clock time. It is exact algorithmic row work for the frozen TRIDAG path.

Report `W(n)/W(16)`.

## Frozen classifications

### VARIABLE_DIMENSION_PRIMITIVES_QUALIFIED

Require:

- all requested dimensions 11, 12, 13 and 16 solve successfully;
- workspace active_nodes exactly equals requested n after each reshape;
- no stale-state leakage;
- algebraic residual gate passes;
- structural work decreases monotonically below n=16;
- manager scratch view remains explicitly non-authoritative.

### FIXED_DIMENSION_LEAK

Any production primitive silently restores or assumes n=16.

### RESHAPE_STATE_LEAK

Any stale value from a previous dimension affects an active solve.

### LINEAR_SOLVE_INCONSISTENT

Any algebraic solve/residual failure.

Frozen aggregate positive classification:

`QUALIFIED_Z28_VARIABLE_DIMENSION_MANAGER_BOOTSTRAP`.

## Positive consequence

A positive Z28 result authorizes the next workunit to bind the already-qualified moving-interface physics onto this variable-dimension manager and run the first real adaptive-vs-full A/B physical benchmark.

## Stop rules

Do not in Z28:

- modify accepted physical semantics;
- introduce lower-tail approximations;
- claim physical speedup from the algebra bootstrap;
- change production defaults;
- add hysteresis/dwell;
- create a second accepted-state owner.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z28

BASELINE: `d43a3ed32d8dbafa9095f1fc717ccfe34b8b7e09`

BRANCH: `research/f-pe-nlglob14z28-variable-dimension-manager`

NEXT SAFE STEP: executable variable-dimension workspace/TRIDAG bootstrap using production primitives.

## Production boundary

Research/bootstrap only.

No production default change.

`LEGACY_NUMERICS` remains production default.
