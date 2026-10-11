# Numerical formulation

The SWAP5 numerical documentation separates three questions that were historically more intertwined in program flow:

1. **What discrete numerical problem is being solved?**
2. **What constitutes a successful numerical candidate?**
3. **When may that candidate become committed model state?**

The first two belong primarily to solver/numerical contracts. The third belongs to the transaction/execution layer.

## Read this section

1. [Richards discretisation and nonlinear solve](richards-solver.md)
2. [Transactional time stepping and acceptance](transactional-time-stepping.md)
3. [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md)
4. [Mass-accounting contract](../verification/mass-accounting-contract.md)
5. [Theory, code and evidence traceability](../status-a/TRACEABILITY.md)

## Reference numerical lineage

The restricted historical reference authority documents an implicit backward finite-difference compartment formulation for the reference Richards route. Storage is evaluated from the actual water-content change and internodal Darcy terms connect neighbouring compartments. The nonlinear residual is solved through the qualified Newton/tridiagonal route.

For the frozen Status-A production baseline, the primary nonlinear owner is `src/legacy/b1_10_port/headcalc.f90`, with the typed reference workspace/state binding and the reference linear-solver module providing explicit scratch, state and solve seams around that compatibility owner. The detailed owner/claim map is recorded by F-DOC25.

The current Status-A claim is bounded: it preserves/admit the qualified reference soil-water core and its later transaction architecture. This section does not turn every historical numerical option into a current SWAP5 capability.

## Primary solve versus auxiliary temporal indicator

The production Richards residual/Jacobian/Newton route and the restricted temporal-indicator operator are different numerical objects.

The Richards solver page documents the primary nonlinear residual, Jacobian, Newton update, backtracking, convergence criteria and linear solve. The temporal indicator is only an auxiliary, fail-closed defect/head-bound operator for a restricted provider/boundary envelope. It does not redefine the production residual and it does not establish a universal nonlinear true-error theorem or application-wide head budget.

Where that indicator is relevant to a current capability, follow the exact capability-specific qualification/admission chain rather than inferring a global accuracy guarantee from its existence.

## Numerical method versus execution policy

A converged nonlinear solve is not sufficient by itself to mutate accepted state. SWAP5 deliberately separates:

- solver status and candidate values;
- hard scientific/numerical assessments such as applicable mass criteria;
- execution-policy decisions such as accept or retry;
- commit/rollback state authority.

This separation is one of the central review targets of SWAP5.

## Time-reference evidence

Historical F-DOC13 documents a bounded temporal-certificate lineage derived from an exact linear backward-Euler problem and independently transferred/qualified only within its stated restricted scope. It explicitly does **not** establish a universal nonlinear Richards true-error theorem or an application-wide accuracy budget.

Where that certificate lineage is relevant to a current capability, use the exact capability-specific authority. Do not infer a global accuracy guarantee from the existence of a numerical indicator.

## Hard boundaries

The numerical review baseline does not claim:

- a universal timestep;
- a universal pressure-head tolerance for every application;
- that shorter timesteps always improve every indicator monotonically;
- that a model-owned temporal indicator overrides mass failure;
- that rejected candidate state can leak into committed state;
- that a performance policy may silently select different physics;
- that RossFast or another post-Status-A solver belongs to the frozen Status-A numerical denominator.
