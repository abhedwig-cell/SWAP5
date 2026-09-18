# F-GC49 — Generic groundwater application orchestration

## Purpose

F-GC49 turns the topology and coupling capabilities admitted in F-GC39 through F-GC48 into one generic production application path.

It is deliberately not another topology experiment. Its purpose is to remove topology-specific qualification wiring from F-GC44 through F-GC47 and replace it with one internal SWAP5–MODFLOW application service.

Production implementation is blocked until F-GC48 is canonically admitted.

## Architectural gap

The repository currently contains two different but compatible execution surfaces.

The Fortran groundwater coupling stack owns SWAP-side transaction semantics, cell-level N:1 reduction, lineage and ledger rules. The live MODFLOW6 backend is implemented by Modflow6PreparedSolveSession in Python/xmipy.

These are intentionally separated:

- mod_groundwater_multiswap_coupler works against groundwater_preparable_exchange_service_t; it does not own the live MODFLOW/XMI prepared-solve session.
- modflow6_prepared_solve_session.py owns XMI pointers and MODFLOW solve lifecycle only; it explicitly does not own predictor/corrector science.
- F-GC39 defines the internal service contract between those responsibilities.
- F-GC42 proves whole-window service composition.
- F-GC44 through F-GC47 prove real live application cases, but do so through qualification-specific C bridges.

F-GC49 closes this application-layer gap.

## Ownership

### SWAP / FMR production participant

Fortran remains the sole owner of committed SWAP state, accepted checkpoints, predictor trials, corrector trials, candidate rollback, candidate publication and kernel revision/time advancement.

No Python component may write SWAP physical state, committed revision or committed time.

### Application-plan materializer

A Fortran production component consumes one admitted F-GC48 topology snapshot plus one predictor response per topology tile.

It emits in canonical topology order:

- one F-GC40 cell response per groundwater cell;
- one F-GC33 linear boundary term per groundwater cell;
- F-GC34 API slot/node bindings;
- immutable routing metadata from cell to tile participants.

The application-plan component is pure composition. It performs no SWAP trial, MODFLOW solve or publication.

### Generic application service

A Python internal service below iMOD Coupler owns the coupled-window control flow.

It consumes only the immutable application plan, a production SWAP participant client, Modflow6PreparedSolveSession and coupling convergence configuration.

It must not own XMI arrays directly. All MODFLOW access remains behind Modflow6PreparedSolveSession.

### MODFLOW backend

Modflow6PreparedSolveSession remains sole owner of XMI pointer acquisition, package array publication, prepare_solve, iterative solve, finalize_solve, non-mutating timestep readiness and one-shot finalize_time_step.

## Window lifecycle

1. Validate/materialize F-GC48 topology.
2. Capture one accepted SWAP origin per tile.
3. Build one predictor response per tile.
4. Fortran application plan performs F-GC40 tile-to-cell reduction, F-GC33 cell-to-linear-term materialization, and F-GC34 cell-to-slot/node binding.
5. The caller has already established MODFLOW prepare_time_step.
6. Acquire package views and call prepare_solve exactly once.
7. On each coupling iteration: publish all cell terms; solve MODFLOW once; require fixed accepted XOLD; route each cell head only to that cell's topology-owned tiles; run all tile correctors from immutable accepted origins; reduce corrector exchanges to one cell-level flux; compare against realized MODFLOW cell exchange.
8. If not jointly converged: discard all nonfinal SWAP candidates, re-anchor per-cell affine intercepts, retain admitted slopes, and continue the same prepared solve.
9. Joint convergence requires MODFLOW converged AND every active cell interface residual within tolerance.
10. Finalize_solve exactly once.
11. Preflight every final SWAP candidate, every prepared ledger and MODFLOW timestep readiness.
12. Cross the first irreversible publication point: finalize_time_step exactly once, commit SWAP candidates in canonical topology order, then commit ledgers in canonical topology order.

## Application-plan contract

The application plan is immutable after materialization.

A minimal plan contains a topology identity/generation, canonical cells with groundwater_cell_id/package_slot/modflow_node_id/tile range/linear term, and canonical tiles with tile_id/swap_lineage_id/ledger_id/groundwater_cell_id/area_fraction.

The plan must not duplicate mutable SWAP state or MODFLOW state.

Materialization fails before any solver mutation when topology is not ready, predictor count is wrong, tile predictor identity is missing or duplicated, predictor lineage disagrees with the owning topology cell, predictor windows differ, F-GC40 rejects cell reduction, F-GC33 rejects a linear term, or an F-GC34 binding cannot be emitted.

## Participant bridge

The production participant bridge should expose the smallest possible ABI:

- capture_origin(tile_id)
- build_predictor_response(tile_id, origin)
- corrector_trial_from_origin(tile_id, origin, prescribed_head)
- discard_candidate(tile_id, candidate)
- publication_ready(tile_id, candidate, window)
- prepare_ledger(tile_id, candidate, window)
- ledger_ready(tile_id)
- commit_candidate(tile_id, candidate, window)
- commit_ledger(tile_id)
- abort_prepublication(tile_id)

The ABI must not expose raw kernel_executor_t, raw committed-state storage, FMR private model objects, or mutable Fortran pointers retained by Python.

Handles may identify participants/candidates, but Fortran remains authority for handle validity and provenance.

## Convergence

For cell c with tiles i and area fractions a_i, q_swap,c = sum_i(a_i * q_swap,i) and r_c = q_swap,c - q_groundwater,c.

A window is coupled-converged only when MODFLOW reports nonlinear convergence and for every active groundwater cell abs(r_c) is within the configured flux tolerance.

The generic service must never reduce multiple residuals to a single cancelling global residual.

## Re-anchoring

The first F-GC49 production envelope preserves the admitted F-GC39 rule: slope is fixed over one coupling window; after a non-converged iteration the affine reference head becomes the current MODFLOW cell head and the affine reference flux becomes the current real SWAP cell-level corrector flux.

No runtime finite-difference tangent is introduced.

## Failure classes

Reversible pre-publication failures include invalid topology/application plan, failed predictor, failed MODFLOW package publication, failed MODFLOW solve, XOLD drift, failed SWAP corrector, non-finite cell residual, coupling-iteration budget exhaustion, finalize_solve failure, and any SWAP/ledger/MODFLOW preflight failure.

The prepared MODFLOW session is invalidated if the window is abandoned.

After successful finalize_time_step, failures are not represented as rollback-safe scientific retry. A later SWAP or ledger publication failure is a hard durability/restart invariant violation.

F-GC49 must not advertise distributed atomic rollback that the live participants cannot provide.

## iMOD Coupler boundary

iMOD Coupler may construct/configure the application service, request advancement of one coupling window, and receive success/retry/failure plus diagnostics.

iMOD Coupler must not run SWAP predictor/corrector iterations, inspect or mutate SWAP candidates, update affine response references, decide per-cell convergence, own MODFLOW prepare_solve iterations, or perform publication ordering.

## First production qualification

After F-GC48 admission, F-GC49 should be implemented in three gated stages.

### F-GC49A — Application-plan materialization

Production Fortran only. Prove that one F-GC48 topology plus tile predictor responses deterministically produces the same F-GC40/F-GC33/F-GC34 cell plan for the F-GC44, F-GC45, F-GC46 and F-GC47 reference topologies.

### F-GC49B — Production participant bridge

Expose the already-admitted FMR participant lifecycle without qualification-specific topology code. Prove same-origin trials, rollback, readiness and kernel-owned commit for multiple participant handles.

### F-GC49C — Generic live application service

Use one implementation to replay F-GC44 1:1, F-GC45 N:1, F-GC46 multi-cell 1:1 and F-GC47 mixed 2:1 plus 1:1. No topology-specific branches are allowed in the service.

Only after all three stages pass owner and independent qualification should F-GC49 be canonically admitted.

## Explicit exclusions

F-GC49 does not expand the prescribed-head/numerical envelope; enable drainage, root uptake, macropores, snow or soil temperature; decide whether heterogeneous N:1 aggregation is scientifically valid; add Ribasim or irrigation; replace F-GC40 or F-GC34 mathematics in Python; move SWAP transaction ownership out of Fortran; or move predictor/corrector ownership into iMOD Coupler.
