# F-GC49C — Generic live groundwater application service

## Scope

F-GC49C materializes the internal SWAP5–MODFLOW coupling-window control flow as a topology-agnostic production Python service. It consumes an immutable application-plan view and a narrow SWAP runtime port while delegating all live MODFLOW/XMI lifecycle operations to the already admitted `Modflow6PreparedSolveSession`.

The service is below iMOD Coupler. It owns coupling-window orchestration only; it owns neither SWAP physical state nor raw XMI arrays.

## Ownership

`Modflow6PreparedSolveSession` remains sole owner of package pointers, `prepare_solve`, iterative `solve`, `finalize_solve`, timestep readiness and one-shot `finalize_time_step`.

The SWAP runtime port remains authoritative for application-plan materialization, accepted-origin capture, cell-level realized-groundwater-flux evaluation, real SWAP correctors, F-GC40/F-GC33 re-anchoring, candidate discard, ledger preparation/preflight and SWAP/ledger publication.

Consequently the Python service contains no F-GC40 cell aggregation, F-GC33 HCOF/RHS algebra, F-GC34 slot publication implementation, topology-specific cell IDs or SWAP committed-state mutation.

## Coupling lifecycle

For each window the service validates one canonical plan, captures accepted SWAP origins, acquires the prepared MODFLOW timestep and opens exactly one prepared solve.

For every outer coupling iteration it publishes the current cell terms through the prepared-solve backend, advances one MODFLOW nonlinear iteration, routes the resulting head for every plan cell to the SWAP runtime, obtains one real SWAP cell-level corrector flux per cell, and compares each cell residual separately.

Coupling converges only when MODFLOW reports nonlinear convergence and every individual cell residual lies within the configured tolerance. Opposite residuals on different cells may never cancel.

If coupling has not converged, the service discards all non-final SWAP candidates and asks the runtime authority to re-anchor the cell terms. MODFLOW X continues in the same prepared solve while XOLD remains fixed under the existing prepared-solve contract.

## Publication boundary

After joint convergence the service finalizes the prepared solve exactly once. It then requires, in order, SWAP publication readiness, ledger preparation, ledger readiness and MODFLOW timestep readiness.

Only after all reversible checks pass does it cross the first irreversible publication point: MODFLOW `finalize_time_step`, then all SWAP commits, then all ledger commits.

A failure after successful MODFLOW timestep publication raises a hard publication/durability invariant. It is not returned as a rollback-safe smaller-window retry.

## Qualification

The deterministic owner gate proves per-cell non-cancellation, conjunctive MODFLOW-plus-all-cell convergence, one prepared solve, reversible preflight failure and hard post-publication failure classification.

The live owner gate sends the previously admitted F-GC47 mixed topology (two real SWAP columns N:1 to one live MODFLOW cell plus one real SWAP column 1:1 to a second cell) through this single production service against MODFLOW6 6.8.0.

The F-GC47 C bridge used by that live test remains qualification-only. F-GC49C does not claim it as a production FMR cross-language ABI.

F-VQ123 independently verifies absence of topology-specific branches/cell mathematics in the production service, per-cell convergence semantics and publication ordering.

## Remaining boundary

F-GC49C admits the generic application-service control flow. If no generic production FMR cross-language binding exists after admission, that binding remains a separately bounded F-GC49D capability. It must expose F-GC49A plan authority and F-GC49B participant handles without promoting F-GC44–47 qualification bridges into production architecture.
