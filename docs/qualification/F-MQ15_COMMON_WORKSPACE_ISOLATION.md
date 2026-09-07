# F-MQ15 — production common-workspace MultiSWAP isolation

F-MQ15 is qualification-only and starts from qualified F-MQ14 head `eebf665d0123feb1e0c6fd694b58ec6635cd7cc2`.

## Why this unit is useful now

F-SI03 has been created but still points at the F-SI02 qualified head; F-VQ09 is still only a checkpoint. Rather than create another bookkeeping-only admission, F-MQ15 exercises the already-qualified F-SI02 production common solver workspace under MultiSWAP-style reuse.

## Executable scope

The gate fetches the exact F-SI02 qualified head `da1d5da0d909c5ce55efa17507b805bffd6b82f9` and uses the pinned production sources:

- `src/solver/mod_soil_water_solver_contract.f90`
- `src/solver/mod_reference_richards_workspace.f90`

A dedicated F-MQ test processes 256 logical columns with worker pools of 1, 2, 4 and 8 workers in forward and reverse column order. Before every logical column the assigned worker workspace is poisoned and then reset. The test requires clean reset, no warm-start leakage, no residual leakage, deterministic per-column signatures across worker counts and orders, and workspace payload scaling with workers rather than logical-column count.

The exact sources and test are compiled and executed at O0 and O2 with OpenMP. O0 and O2 output must be identical.

## Qualification boundary

A green F-MQ15 gate qualifies only the common-layer executable prerequisites for:

- P06 scratch/workspace isolation;
- P19 scratch poisoning/reset.

It does **not** qualify reference-Richards physics, real B1.10 execution, full solver reentrancy, physical water-balance identity, solver-route identity, the production MultiSWAP runtime/backend, or any coupling property. Therefore the original matrix coverage remains 27 synthetic, 0 real-physics and 0 production-runtime rows.

No production source is modified by F-MQ15.
