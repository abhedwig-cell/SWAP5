# F-PE-MULTI01 P0 result — generic parallel worker-pool scaling

Date: 2026-09-27

Status: `PASS_SCALING_MAP`

PR:
`#661 — F-PE-MULTI01: current-canonical MultiSWAP scaling rebaseline`

Authority run:
`36307138967`

## Scope

P0 measures the already admitted generic physical worker-pool on current canonical for N=100, 1,000 and 10,000 columns, batch sizes 1, moderate and large, and worker counts 1, 2 and 4.

No production source is modified.

## Result

Batch size 1 serializes physical work by construction:

- max simultaneous physical solves = 1 for 1, 2 and 4 requested workers;
- extra workers are therefore overhead and make runtime worse.

With multi-column batches, real overlap is observed:

- 2 workers -> max simultaneous = 2;
- 4 workers -> max simultaneous = 4;
- all requested columns execute and commit;
- aggregate mass is complete;
- no retries occur in this clean scaling fixture.

Representative speedups:

N=100:
- batch 64: 2 workers 1.64x, 4 workers 2.78x;
- batch 100: 2 workers 2.24x, 4 workers 2.89x.

N=1,000:
- batch 64: 2 workers 1.83x, 4 workers 2.15x;
- batch 1,000: 2 workers 1.73x, 4 workers 1.86x.

N=10,000:
- batch 64: 2 workers 1.42x, 4 workers 1.58x;
- batch 1,024: 2 workers 1.46x, 4 workers 1.64x.

At N=10,000 and batch 1,024:

- 1 worker: 11.01 us/column;
- 2 workers: 7.54 us/column;
- 4 workers: 6.71 us/column.

## Interpretation

The existing scheduler is genuinely parallel when batches contain enough independent columns.

The main result is not NO_PARALLEL_GAIN. It is:

`GOOD_SCALING_WITH_LARGE_N_EFFICIENCY_LOSS`.

The 4-worker efficiency falls to about 0.41 at N=10,000. That loss may reflect synchronization, memory/cache effects, worker scheduling or other shared-runtime overhead. P0 alone does not distinguish them.

Batch=1 is an intentionally serial scheduling regime and must not be used as evidence that the worker pool itself is broken.

## Handoff

Generic worker-pool capability is sufficient to justify testing parallel execution of the actual production groundwater participant route.

That production route currently differs structurally because participants share one mutable serialized Reference backend and therefore execute serially.
