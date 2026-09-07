# F-SI02 Reference solver interface and worker workspace

## Status

F-SI02 introduces the first compileable F-SI-owned soil-water solver contract behind the F-KT transaction boundary. It does not yet route the B1.10 reference Richards calculation through that contract.

Source basis:

- F-SI01 qualified head: `ae6da038ee7e98dfe1758f5f86b4be0fb48b4743`
- F-CI18 canonical closeout: `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`
- qualified production-source head: `da5026d8b87ad2f3c7912360891839a120ecccb6`
- corrected legacy oracle: B1.10
- consumed F-KT boundary: `integration/f-kt/F-KT01_FSI_BOUNDARY.json` at `62f27672bbb74066ece202de8898597e655aed3d`, blob `ee1a153c30bbae9416ce08414e8b56049d3d14db`

## Common solver contract

`src/solver/mod_soil_water_solver_contract.f90` defines the F-SI-owned service seam. The abstract solver signature is conceptually:

`solve(request, workspace, result)`

The request separates:

- a shared soil-water parameter set;
- a base physical-state snapshot;
- boundary conditions;
- numerical configuration selected outside solver internals;
- a hydraulic evaluation context;
- the step duration supplied by the caller.

The result separates candidate physical state, unrounded top and bottom fluxes, unrounded mass-balance residual, solver diagnostics and a reserved interface-sensitivity field `dh_bottom_dq_bottom`.

The solver does not own commit, rollback, checkpoint meaning or generic `[t0,t1]` semantics. A returned candidate is not committed by F-SI.

## Evaluation context

The evaluation context has explicit provider seams for:

- constitutive hydraulics;
- source and sink evaluation;
- top-boundary evaluation;
- optional macropore exchange.

This is deliberately an isolation seam, not new physics. F-SI02 does not replace `watcon`, `hconduc`, `moiscap`, `dhconduc`, `RootExtraction`, `boundtop`, `MACROPORE` or other reference formulas. Binding those existing functions behind the providers belongs to a later source-bound slice.

## Worker-owned workspace

`src/solver/mod_reference_richards_workspace.f90` contains the heavy scratch categories currently visible in HeadCalc:

- lower, main and upper Jacobian bands;
- residual and Newton delta vectors;
- source and sink temporaries;
- conductivity derivative temporary;
- old-head storage used during iteration;
- vertical-flux and head-gradient temporaries;
- convergence flags;
- numerical warm-start head;
- solver diagnostics.

Allocation is per worker or active solve job. The workspace is reusable across logical columns after reset. It is not persistent column state.

The workspace has explicit `initialize`, `reset`, `poison` and `release` operations. Poisoning uses IEEE quiet NaNs for real scratch so accidental reuse becomes observable in focused tests.

## Important constness limitation

The parameter set is shared through a Fortran pointer to avoid imposing a per-column copy of immutable geometry and hydraulic identity. The API contract says the target is read-only. Fortran `intent(in)` does not provide the same deep const guarantee for a pointer target that a const reference would provide in some other languages. Therefore immutability is currently a contract plus qualification requirement, not a complete compiler guarantee.

F-SI implementations must not mutate the parameter target. If this proves too weak during binding, F-SI must harden the handle/provider boundary without moving immutable parameters into per-column state.

## What is qualified in F-SI02

The focused gate checks:

- O0 and O2 compilation;
- shared immutable-parameter reference identity;
- deep-copy independence of the base physical-state carrier;
- workspace reset and scratch poisoning;
- independent workspaces under 1, 2, 4 and 8 OpenMP threads;
- warm-start reset;
- exact preservation of HeadCalc, SoilWater, the existing worker context and transaction source blobs;
- absence of `SAVE`, file I/O and direct legacy-global imports in `src/solver`;
- the previous F-SI01 gate.

This does not yet qualify full reference-Richards reentrancy, water-balance identity or solver-route identity because HeadCalc is not yet bound to the common interface.

## Invariant assessment

F-SI02 advances invariants 1, 3, 4, 5, 6, 16, 20, 21, 22, 26 and 27 by creating a common solver seam and worker-owned heavy workspace. It protects invariants 13, 23 and 25 by leaving equations, physical process choices, numerical-policy selection and the reference source path unchanged. It reserves rather than implements invariant 14 interface sensitivity. Invariant 24 is not claimed as a performance qualification here.

## Next slice

F-SI03 should bind the existing B1.10 reference Richards route to the F-SI-owned request/result/workspace seam in a narrow adapter/isolation step. The acceptance target is behavioral identity: no formula change, no numerical-policy change, unrounded water accounting unchanged, and exact route/iteration comparison where observable.
