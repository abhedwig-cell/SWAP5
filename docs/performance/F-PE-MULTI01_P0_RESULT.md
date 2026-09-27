# F-PE-MULTI01 P0 result — generic parallel worker-pool scaling

Date: 2026-09-27

Status: `PASS_SCALING_MAP`

PR:
`#661 — F-PE-MULTI01: current-canonical MultiSWAP scaling rebaseline`

Current-head authority:
- branch head exercised: `0cb0811fc4118c4acafe36bc182c65051cc1943b`;
- workflow run: `36307581257`;
- job: `p0-scaling`.

## Scope

P0 measures the already admitted generic physical worker-pool on the current post-BASE01 canonical line for N=100, 1,000 and 10,000 columns, batch sizes 1, moderate and large, and worker counts 1, 2 and 4.

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

Representative current-head speedups:

N=100:
- batch 64: 2 workers 1.57x, 4 workers 2.92x;
- batch 100: 2 workers 1.71x, 4 workers 3.05x.

N=1,000:
- batch 64: 2 workers 1.71x, 4 workers 1.83x;
- batch 1,000: 2 workers 1.51x, 4 workers 1.79x.

N=10,000:
- batch 64: 2 workers 1.44x, 4 workers 1.59x;
- batch 1,024: 2 workers 1.45x, 4 workers 1.61x.

At N=10,000 and batch 1,024:

- 1 worker: 13.19 us/column;
- 2 workers: 9.08 us/column;
- 4 workers: 8.20 us/column.

## Interpretation

The existing scheduler is genuinely parallel when batches contain enough independent columns.

The stable conclusion is:

`GOOD_SCALING_WITH_LARGE_N_EFFICIENCY_LOSS`.

At N=10,000 the 2-worker result approaches, but does not reach, the frozen 1.5x successor gate in this generic fixture. The 4-worker result remains well below 2.2x.

That efficiency loss may reflect synchronization, memory/cache effects, worker scheduling or other shared-runtime overhead. P0 alone does not distinguish them.

Batch=1 is an intentionally serial scheduling regime and must not be used as evidence that the worker pool itself is broken.

## Handoff

Generic worker-pool capability is sufficient to justify testing parallel execution of the actual production groundwater participant route.

That production route currently differs structurally because participants share one mutable serialized Reference backend and therefore execute serially.
