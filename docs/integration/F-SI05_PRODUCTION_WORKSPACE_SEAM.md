# F-SI05 Production HeadCalc workspace seam

## Status

`QUALIFIED_PRODUCTION_WORKSPACE_SEAM_FOCUSED_ROUTES_ONLY`

F-SI05 converts the source-bound F-SI04 HeadCalc workspace transformation into committed production source without changing Richards equations, convergence criteria, numerical-policy selection, transaction semantics or generic time semantics.

## Exact lineage

- F-SI04 qualified base: `c76f794b93522bea3a80a6880bc95ef5671cb914`
- corrected legacy oracle: B1.10
- production materialization commit: `1fe1bf4790955594290ba1233d5684542799bf9e`
- first qualified implementation checkpoint: `56c21448a2a0be716d497ac34db8c5eec60dd246`
- workflow run: `34124675751`
- job: `101750448325`
- compiler: GNU Fortran 13.3.0

The F-KT/F-SI boundary was re-read at F-KT head `bfb5bd7dca2b71232e1f0a329e81ac121ac894ba` and remains exact blob `ee1a153c30bbae9416ce08414e8b56049d3d14db`.

## Production changes

Three F-SI-owned source files are structurally changed.

1. `src/legacy/b1_10_port/headcalc.f90`
   - production blob `e22251c8f562839857cdb7a609a8148d1f2d58f8`;
   - signature is `headcalc(worker, fsi_workspace)`;
   - both arguments remain optional for explicit legacy compatibility;
   - the common solver adapter passes an explicit workspace;
   - the legacy `soilwater.f90` caller remains source-compatible through `headcalc(worker)`;
   - main Newton, residual, Jacobian and hydraulic scratch use `fsi_ws` rather than automatic arrays or `ctx%headcalc%dkdh`.

2. `src/solver/mod_reference_richards_workspace.f90`
   - production blob `93285b2ca24669494c93c00403e3783fca6758e9`;
   - adds band-solver `band_matrix`, `band_aux`, `band_rhs` and `band_pivots`;
   - these fields participate in allocation, reset, poisoning, release and payload accounting;
   - they remain worker/active-solve-job scratch and are not persistent column state.

3. `src/adapter/mod_reference_richards_legacy_binding.f90`
   - production blob `e02882bd45f67b42ede118de14a6b5b8b16fdb80`;
   - its existing `ws%richards` workspace is now explicitly passed to HeadCalc.

`soilwater.f90`, the transaction source, the worker execution context and the common solver contract are unchanged by F-SI05.

## Executable qualification

The F-SI05 gate executes the real committed HeadCalc source against the exact F-SI04 preimage. It covers two linear-solve routes:

- normal tridiagonal route;
- forced TRIDAG failure followed by the real alternative band solver.

At O0 and O2, the exact F-SI04 preimage, the explicit-workspace production call and the one-argument compatibility call produce byte-identical focused outputs. The test also checks A/B/A repeat identity, solver route and iteration diagnostics, scratch poisoning/reset, and the unrounded focused equation residual.

The F-SI03 adapter executable behavior remains unchanged at O0/O2. The common F-SI workspace test remains isolated at 1, 2, 4 and 8 OpenMP threads at O0/O2.

This is not a claim that real HeadCalc itself is already safe for 1/2/4/8 concurrent columns. The common workspace storage is qualified for that isolation; remaining legacy cross-call state still blocks the stronger reentrancy claim.

## Mass conservation

Mass conservation remains a hard invariant. F-SI05 proves exact identity of the unrounded focused HeadCalc equation residual on the admitted fixture, including the forced band fallback route. It does not execute the full SWAP water-accounting chain, so full unrounded SWAP water-balance identity remains unqualified in this work unit.

## Explicit holds

The following are intentionally not resolved or qualified in F-SI05:

- the `legacy_worker` `SAVE` object used only when no worker is passed;
- ownership of cross-call `ctx%history%flwarn`, `iwarn` and `nstep`;
- real HeadCalc concurrency/order-independence across 1/2/4/8 workers;
- macropore execution;
- implicit conductivity routes;
- minimum-timestep-specific routes;
- non-free-drainage bottom-boundary modes outside the admitted focused fixture;
- full SWAP unrounded water-balance qualification;
- interface response tangent implementation;
- MultiSWAP production admission.

Existing compiler warnings around guarded `i-1`, potentially uninitialized `sum1`, and unsupported `swkmean`/`dkmean` behavior remain separate audit items. F-SI05 does not alter them while changing ownership.

## Architecture invariant assessment

F-SI05 is consistent with invariants 1, 3, 4, 5, 6, 7, 8, 13, 14, 16, 20, 21, 22, 23, 24, 25, 26, 27 and 29. In particular, the heavy band-solver arrays now scale with active workspaces rather than logical columns, solver scratch remains outside persistent state, and no F-KT transaction contract or solver physics is changed.

## Next slice

F-SI06 should resolve the remaining `legacy_worker SAVE` and the cross-call history ownership before claiming real solver reentrancy. It should then qualify order independence and real HeadCalc execution with 1, 2, 4 and 8 workers on the admitted reference routes, while retaining exact source-bound numerical behavior and hard mass-conservation checks.
