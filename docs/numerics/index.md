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

The restricted historical reference authority documents an implicit backward finite-difference compartment formulation for the reference Richards route. Storage is evaluated from water-content change and internodal Darcy fluxes connect neighbouring compartments. The nonlinear residual is solved through the qualified Newton/tridiagonal route.

The current Status-A claim is bounded: it preserves/admit the qualified reference soil-water core and its later transaction architecture. This section does not turn every historical numerical option into a current SWAP5 capability.

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
- that a performance policy may silently select different physics.
