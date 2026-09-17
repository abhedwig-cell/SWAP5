# Numerical formulation

The SWAP5 numerical documentation separates four questions that were historically more intertwined in program flow:

1. **What discrete numerical problem is being solved?**
2. **What constitutes a successful nonlinear candidate?**
3. **What additional numerical indicators are available, and inside which envelope?**
4. **When may a candidate become committed model state?**

The first three belong primarily to solver/numerical contracts. The fourth belongs to the transaction/execution layer.

## Read this section

1. [Richards discretisation and nonlinear solve](richards-solver.md)
2. [Restricted Richards temporal indicator](richards-temporal-indicator.md)
3. [Transactional time stepping and acceptance](transactional-time-stepping.md)
4. [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md)
5. [Mass-accounting contract](../verification/mass-accounting-contract.md)
6. [Theory, code and evidence traceability](../status-a/TRACEABILITY.md)

## Reference numerical lineage

The restricted frozen reference authority documents an implicit backward compartment formulation for the reference Richards route. Storage is evaluated from the actual water-content endpoint change and internodal Darcy fluxes connect neighbouring compartments. The bounded `SWKIMPL=0` route keeps face conductivity frozen during the nonlinear iteration while moisture capacity follows the current pressure-head iterate.

The nonlinear residual is solved through the reference Newton/tridiagonal route with bounded backtracking and an explicit band-solver fallback if the tridiagonal solve reports failure.

The current Status-A claim remains bounded: the documentation explains the qualified reference soil-water core and its transaction architecture. It does not turn every historical numerical switch into a current SWAP5 capability.

## Numerical method versus execution policy

A converged nonlinear solve is not sufficient by itself to mutate accepted state. SWAP5 deliberately separates:

- solver status and candidate values;
- optional numerical indicators;
- hard scientific/numerical assessments such as applicable mass criteria;
- execution-policy decisions such as accept or retry;
- commit/rollback state authority.

This separation is one of the central review targets of SWAP5.

## Temporal-indicator evidence

The reference solver exposes a restricted temporal indicator only inside an explicit applicability envelope. It uses the change in consecutive discrete right derivatives, candidate moisture-capacity mass weights and one additional tridiagonal defect solve. It performs no additional full nonlinear solve.

That implementation is deliberately documented separately from the Richards residual/Jacobian because its existence does **not** establish a universal nonlinear true-error theorem or an application-wide accuracy budget.

Historical F-DOC13 also records a bounded temporal-certificate lineage derived from an exact linear backward-Euler problem. Where that lineage is relevant to a current capability, use the exact capability-specific authority; do not infer a global guarantee merely from the existence of a numerical indicator.

## Hard boundaries

The numerical review baseline does not claim:

- a universal timestep;
- a universal pressure-head tolerance for every application;
- that shorter timesteps always improve every indicator monotonically;
- that a model-owned temporal indicator overrides mass failure;
- that rejected candidate state can leak into committed state;
- that a performance policy may silently select different physics;
- that post-Status-A RossFast work belongs to the frozen Status-A scientific denominator.
