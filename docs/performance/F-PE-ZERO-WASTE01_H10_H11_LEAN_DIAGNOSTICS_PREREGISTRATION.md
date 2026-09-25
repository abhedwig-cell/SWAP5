# F-PE-ZERO-WASTE01 H10/H11 — lean production diagnostics and serialized tracking

Date: 2026-09-25

Status: `IMPLEMENTED_PENDING_FULL_QUALIFICATION`

## Scope

H10/H11 remove runtime administration from the production standalone MultiSWAP route when the caller does not request diagnostic products.

No solver, physics, state, transaction, water-balance or coupling calculation is changed.

## H10 — diagnostic materialization

The serialized runtime historically materialized, for every column:

- a diagnostics object;
- column/template/backend/execution metadata;
- an allocatable `worker_assignments(1)` vector;
- aggregate/summary diagnostics.

The active production application bootstrap now requests:

- `materialize_worker_assignments=.false.`
- `materialize_summary_diagnostics=.false.`
- `materialize_diagnostic_metadata=.false.`
- `materialize_column_diagnostics=.false.`

The generic runtime retains the diagnostic-on default for existing callers. H10 therefore removes work only from the production route that does not consume these products.

The shared-runner dispatch benchmark at N=10,000 measured approximately:

- worker-assignment materialization: 391 microseconds/dispatch;
- diagnostics metadata without worker assignment: 79 microseconds/dispatch;
- bare diagnostics-array allocation: 53 microseconds/dispatch.

These elapsed values are observational only. The portable claim is that per-column allocation/materialization is absent on the lean production route.

## H11 — serialized concurrency tracking

The generic runtime tracks simultaneous physical solves with OpenMP atomic increment/decrement operations when summary or runtime diagnostics require the metric.

The active runtime derives:

`track_physical_concurrency = materialize_summary_diagnostics OR present(runtime_diagnostics)`

Therefore the lean production route from H10 also disables concurrency tracking. The solver remains serialized; only diagnostic observation work is skipped.

Diagnostic callers retain the original tracking behavior.

## Gates

1. Production application bootstrap gate PASS.
2. Serialized runtime diagnostic-on callers retain expected diagnostic products.
3. Atomic tracking microbenchmark PASS.
4. No accepted physical state, transaction result or mass-accounting output changes on the lean production route.
5. H10/H11 do not alter generic defaults; omission remains opt-in by explicit production-call arguments.
6. Source changes to the serialized runtime or production bootstrap must retrigger the H11 workflow.

## Boundary

This is zero-waste only because the omitted products are not consumed by the production standalone caller.

If a future caller requires worker assignment, column diagnostics, summary diagnostics or maximum-concurrency evidence, those products must be explicitly requested and the associated work is then required.
