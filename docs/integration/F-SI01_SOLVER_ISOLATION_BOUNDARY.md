# F-SI01 Canonical solver-isolation boundary

## Status and source binding

F-SI01 is a source-bound structural inventory for the reference Richards path. It is based on `integration/f-ci-canonical` closeout head `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`, whose direct development-baseline parent is `1eceed967b12396b8bbc832f897376378463adce`. The qualified production-source head remains `da5026d8b87ad2f3c7912360891839a120ecccb6`. F-VQ07 admits this canonical development baseline for downstream qualification but does not qualify the parallel backend or overall SWAP5 release.

No historical S13b postimage is treated as current production source. Historical S13b HeadCalc, RWU, evaluation-context, result-API, oxygen-provider, transaction-accounting and serial/parallel evidence is recorded only as handoff evidence until exact Git provenance is resolved. Current canonical ADRs and tests with exact blob identity may be reused directly.

The locally available `SWAP_4.3.1(6).zip` is explicitly excluded as oracle/source because its SHA-256 does not match the repository-pinned B0 source archive hash.

F-SI01 changes no production solver source, formula, physical option, numerical-policy value, transaction lifecycle or time semantics.

## Current isolation seam

The current `headcalc` routine still crosses the intended solver boundary in four ways.

1. It imports and mutates legacy module-global physical state and numerical controls.
2. It falls back to a `SAVE`-like `legacy_worker` singleton when no worker context is passed.
3. Most Newton, Jacobian and linear-solve arrays are still automatic local scratch even though the canonical worker context already has storage for most HeadCalc scratch.
4. Newton/evaluation directly invokes or reads shared process modules including constitutive hydraulics, RootExtraction, top boundary/runoff, macropores, drainage, irrigation, snow and frost.

`MOD_SoilWater` is the direct legacy caller through `call headcalc(worker)`. HeadCalc's automatic local arrays are not directly addressable by other modules, but the current solver still depends on shared module state. The F-SI01 executable gate scans all `src/**/*.f90` for direct HeadCalc calls and worker-internal references so unexpected new dependencies fail closed.

## Ownership boundary

The target is one logical solver call:

`solve(request, workspace) -> result`

`request` contains read-only immutable soil/hydraulic parameters, the F-KT-owned base physical state view, boundary/forcing data, solver numerical configuration and a read-only hydraulic evaluation context.

`workspace` is owned by a worker or active solve job. It contains Newton vectors, Jacobian bands, linear-solve storage and reconstructible constitutive/evaluation temporaries. It contains no committed state and has no commit/rollback authority.

`result` contains candidate physical state, unrounded boundary fluxes and mass-accounting terms, hydraulic outputs, convergence/retry information, diagnostics and an optional reserved interface-sensitivity field such as `dh_bottom_dq_bottom`.

Only full reference Richards is admitted in this work unit. The common interface shape stays open for later coarse Richards or reduced-order implementations, but neither is implemented here.

## F-KT and F-SI boundary

F-KT owns checkpoint, commit, rollback, transaction lifecycle, committed-state ownership, generic `[t0,t1]` semantics and reference temporal acceptance.

F-SI owns solver reentrancy, reference Richards isolation, hydraulic evaluation context, worker solver workspace and solver result/diagnostic contracts.

A solver call may return a candidate and retry advice. It may not commit, roll back, mutate committed input or redefine temporal acceptance. F-SI01 requires no shared kernel-type change. If a later isolation slice does, the minimal contract must be recorded and coordinated with F-KT before changing the shared type.

## Why heavy solver data need not live per column

For `n` active soil nodes, the current `a23bu_headcalc_scratch_t` already allocates `11*n + 2` real elements and `2*n + 3` logical elements. The nested band solve additionally uses `5*n` real elements and `n` integer elements. These values have attempt-local numerical meaning and can be reconstructed.

Therefore the heavy solver storage can scale with active workers/jobs, `O(W*n)`, rather than logical columns, `O(C*n)`. This proof is conditional on resolving cross-call history such as `flwarn`, `iwarn` and `nstep`: if those are column-history dependent, they cannot be left as generic reusable worker state.

This is an ownership/layout proof, not a performance benchmark and not a qualification of the MultiSWAP parallel backend.

## Focused qualification plan

F-SI01 itself can execute two source-bound gates immediately: exact pinned source/blob checks plus the existing O0/O2 OpenMP worker-context gate. The production common solver interface does not yet exist, so the full solver-isolation matrix is specified now and becomes executable as F-SI02/F-SI03 expose the boundary.

The required matrix is repeated-call identity, order independence, 1/2/4/8 worker isolation where technically supported, scratch poisoning, cloned-state identity, no cross-column leakage, O0/O2, unrounded mass conservation and unchanged route/iteration behavior. F-SI introduces no new numerical tolerance. Existing qualified reference acceptance and unrounded mass-accounting contracts remain authoritative.

## Next slices

1. F-SI02 introduces reference-solver request/result/evaluation-context types behind the F-KT boundary without formula changes.
2. F-SI03 routes Newton, Jacobian and linear-solve scratch through worker workspace and adds poison/reuse tests.
3. F-SI04 isolates constitutive hydraulic evaluation behind a read-only provider/context.
4. F-SI05 isolates RootExtraction, top-boundary and optional macropore callbacks without changing their physics.
5. F-SI06 removes `legacy_worker` from the reentrant production path and resolves cross-call history ownership.
6. F-SI07 returns candidate state, unrounded accounting, diagnostics and optional interface sensitivity without transaction side effects, coordinating shared-type changes with F-KT.
7. F-SI08 runs the complete canonical reentrancy matrix.
8. F-SI09 qualifies the common soil-water interface for reference Richards and records readiness for later alternative solvers.

The machine-readable source binding, full ownership inventory, invariant assessment, historical-evidence classification and test matrix are in `integration/f-si/F-SI01_BASELINE.json`. The exact logical interface is in `integration/f-si/F-SI01_SOLVER_INTERFACE_CONTRACT.json`.
