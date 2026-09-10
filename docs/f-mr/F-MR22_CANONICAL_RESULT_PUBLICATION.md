# F-MR22 — Canonical MultiSWAP result publication

## Source binding

Candidate under remediation: `4b6807c1d78c0c7d8bfe0f7a03a4c6c07d4444b9`.

Independent F-MQ26 showed that the scheduler already computes deterministic canonical execution order, but `fmr_run_parallel_physical_multiswap` returns `results(:)` and `diagnostics(:)` in caller input order. With reversed input the first returned element had dispatch ordinal 7 rather than 1.

## Narrow remediation

Keep all execution, state mutation, aggregation and mass accounting indexed exactly as before. Only after internal execution and deterministic reduction are complete, materialize the public result and diagnostic arrays in the canonical order already defined by `fmr_build_execution_order`.

The same publication rule applies to the worker-pool entrypoint for worker count 1, admitted 2/4-worker execution, and fail-closed output paths. The underlying serialized runtime API is not changed in this workunit.

No physics, solver, tolerances, batching, worker assignment, aggregate reduction, or state-handle mapping changes are permitted.

## Qualification target

The F-MQ26 reversed-input sentinel must change from a reproduced failure to exact PASS, while the previously green scientific matrix, hard mass gate, rejection isolation, true overlap control, 2-vs-4 identity, 2/4/2 replay and O0/O2 identity remain unchanged.
