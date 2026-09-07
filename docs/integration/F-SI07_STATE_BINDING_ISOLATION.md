# F-SI07 reference attempt-state binding isolation

## Status

`QUALIFIED_EXPLICIT_ATTEMPT_STATE_BINDING_PROCESS_BRIDGE_BLOCKED`

F-SI07 isolates the direct mutable Richards request/candidate state from the common reference adapter's legacy module-global translation. The new carrier is solver-owned active-solve state. It is not committed column state, not checkpoint/rollback authority and not Newton/Jacobian scratch.

The qualification deliberately stops before full real-HeadCalc parallel admission. HeadCalc still bridges its explicit state to legacy module globals around process/evaluation calls such as `RootExtraction`, `boundtop` and `pondrunoff`. Those calls must be isolated behind explicit evaluation providers before concurrent real reference execution can be admitted.

## Exact basis

- F-SI06 qualified head: `2fa63c41a4d7248ab7f4b5af46f72caddfda4f29`
- corrected legacy oracle: B1.10
- F-CI18 canonical closeout: `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`
- qualified production-source head: `da5026d8b87ad2f3c7912360891839a120ecccb6`
- F-KT06 qualified head observed at start: `42872c266bc6f4fbf6815b1facbc3ed5d64df19a`
- F-KT06 optional-continuation contract blob: `64f285ac6ae89297ca221048c2ff55cc580e3492`

F-KT07 was observed later on `integration/f-kt` while F-SI07 was closing. At the observed head it was persisted but explicitly `NOT_TESTED` and `NOT_QUALIFIED`; it is not consumed as F-SI07 qualification evidence.

## Ownership result

### F-KT remains owner of accepted physical continuation

F-SI07 changes no F-KT source or shared kernel type. Checkpoint, trial creation, candidate acceptance, commit, rollback and generic `[t0,t1]` semantics stay entirely outside the soil-water solver.

The F-KT06 rule remains authoritative: physics-affecting cross-call continuation belongs to the opaque per-column transaction-state lifecycle. F-SI07 does not move `nstep` or any optional macropore continuation into worker or solver state.

### Active-solve reference state

`reference_richards_state_binding_t` contains the direct Richards working/candidate fields needed while a solve is active:

- base-state mirrors: `hm1`, `thetm1`, `pondm1`, `gwlm1`;
- mutable candidate state: `h`, `theta`, `pond`, `gwl`;
- derived hydraulic state: `k`, `kmean`, `dimoca`;
- boundary working state: `qtop`, `qbot`, `hbot`, `gwlinp`;
- outcome state: `fllowgwl`, `fldecdt`, `numbit`.

The carrier is owned by the reference legacy solver workspace and is reconstructed from the solve request/current legacy compatibility context for each call. It is not persistent per logical column and contains no commit or rollback authority.

### Worker scratch remains separate

Newton vectors, residuals, Jacobian bands, tridiagonal/band solve storage, constitutive temporaries and warm-start scratch remain in `reference_richards_workspace_t`. F-SI07 does not combine them with the physical attempt-state carrier.

## Source change

HeadCalc now accepts:

`headcalc(worker, fsi_workspace, history, state_binding)`

The direct Richards state references in the executable solver body use the supplied `state_binding`. The common reference adapter initializes `ws%state` from `request%base_state`, invokes HeadCalc with that state, and copies the candidate/result fluxes back from `ws%state`.

The adapter no longer writes the request pressure head and water content directly into the global `h` and `theta` arrays as its common-path binding mechanism.

A local integer `solver_numbit` remains the Fortran DO-loop carrier; its value is copied into `state_binding%numbit` each nonlinear iteration. This is a structural language requirement only. The qualified focused replay demonstrates unchanged iteration count and solver output.

For source compatibility, calls without `state_binding` still load a local carrier from legacy globals and publish it back on return.

## Remaining process bridge

F-SI07 intentionally retains explicit helper calls around legacy process/evaluation routines:

- publish explicit state to the legacy compatibility globals;
- call the existing process routine unchanged;
- absorb its state effects back into the explicit state carrier.

This bridge is visible in source and is a hard blocker for concurrent production admission. It prevents F-SI07 from presenting partial isolation as full reentrancy.

The main remaining dependencies include:

- `MOD_top` and `boundtop` / `pondrunoff`;
- `MOD_rootextraction:RootExtraction`;
- source/sink globals such as drainage, irrigation and root uptake;
- forcing/process globals such as rain, melt, runon, evaporation demand and ponding controls;
- external numerical configuration globals;
- constitutive/grid context that is still reached through legacy modules;
- legacy diagnostic histogram `itnumb`.

These are F-SI08-class isolation work, not transaction-state work.

## Executable qualification

The focused F-SI07 gate was executed on checkpoint `ba1cc4eaf796efe53d136c79374d567f996a04bf` using GNU Fortran 13.3.0.

The gate demonstrates:

1. the F-KT transaction source, worker context, common solver contract and existing reference workspace are unchanged from F-SI06;
2. direct HeadCalc mutable Richards state is source-bound to `state_binding`;
3. the attempt-state carrier deep-copies and cannot contaminate another carrier;
4. the real F-SI06 HeadCalc preimage and F-SI07 explicit-state route are output-identical at O0 and O2 on the normal tridiagonal route;
5. the same identity holds on the forced real band-solver fallback route;
6. focused serial A/B/A identity remains intact;
7. scratch poisoning remains clean;
8. solver route, nonlinear iterations, Jacobian builds, linear solves and alternative-solver use remain identical on the focused fixture;
9. the focused unrounded Richards equation residual remains within machine precision and unchanged from the preimage;
10. a state-mutating HeadCalc test double confirms the common adapter passes request state and receives candidate state through the explicit carrier at O0 and O2;
11. the F-KT transaction/worker substrate regression remains green;
12. full real parallel admission is fail-closed while the process/evaluation global bridge remains.

## Mass conservation

Mass conservation remains absolute. F-SI07 does not introduce a rounded balance proxy and does not relax a mass criterion. The focused real-HeadCalc replay retains the same unrounded equation residual as F-SI06 and closes within machine precision on the admitted fixture.

This is not a qualification of the full SWAP water-accounting chain. Full unrounded SWAP mass identity remains a downstream qualification requirement.

## Compiler holds

The existing guarded-index warnings, possible uninitialized `sum1`, and possible uninitialized `dkmean` result for unsupported `swkmean` remain visible. F-SI07 does not repair them because doing so would mix source/numerical audit changes with state isolation.

The F-SI07 state carrier test also emits non-fatal direct real-comparison warnings. These comparisons are test-only exact-value ownership checks and do not alter production numerics.

## Invariant assessment

Within its admitted scope, F-SI07 is consistent with invariants 1, 3, 4, 5, 6, 7, 8, 13, 16, 20, 21, 22, 23, 25, 26, 27 and 29.

In particular, physical attempt state is separated from solver scratch; no new persistent per-column scratch is introduced; F-KT transaction ownership is preserved; reference physics and numerical policy are unchanged on the qualified route; and no MultiSWAP/parallel admission is inferred from incomplete isolation.

## Not qualified

F-SI07 does not qualify:

- concurrent real HeadCalc execution with 1, 2, 4 or 8 workers;
- top-boundary/source-sink/process-provider reentrancy;
- macropore production execution or its composed transaction binding;
- implicit-conductivity execution;
- minimum-timestep execution;
- non-free-drainage lower boundaries;
- full unrounded SWAP water-balance identity;
- an interface response tangent;
- production MultiSWAP.

## Next slice

F-SI08 should isolate the remaining process/evaluation dependencies behind explicit provider/context calls so the common reference route no longer publishes/absorbs state through shared legacy module globals. Only after that removal is a deterministic real HeadCalc 1/2/4/8 reentrancy qualification meaningful.
