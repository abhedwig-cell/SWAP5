# F-PE-MULTI07 — in-process mode-7 population performance result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-multi07-mode7-population-inprocess`

Qualified postimage:
`cd7ba6c02d5dc55781e58a2128bf21741451499c`

Canonical baseline:
`integration/f-ci-canonical@84f4861c4a21e942d2e4954004a05fab39f31083`

Workflow run:
`36755581238`

Job:
`110024854345`

Conclusion:
SUCCESS.

## Question

Does the canonically admitted MULTI06 in-process worker pool preserve the frozen
ELASTIC71 population semantics, and does 2/4-worker execution improve throughput
for the already admitted GENERATED ELAS + mode-7 + 0.20 cm policy?

## Frozen population

Exactly the ELASTIC71 source-weighted 1024-column population was reused:

| profile | soil unit | columns |
| --- | --- | ---: |
| 9024010 | Hn21 | 363 |
| 8060 | zEZ21 | 292 |
| 9024090 | cHn21 | 202 |
| 90210030 | pZg23 | 167 |

Each profile used its own exact frozen geometry and therefore its own
profile-specific executable. Within each executable the canonical MULTI06 worker
pool executed the complete profile batch in-process.

## Deterministic result

All worker counts reproduce the frozen ELASTIC71 authority exactly:

| workers | completed | committed | retries | mass failures | rejected |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1024 | 1024 | 1522 | 0 | 0 |
| 2 | 1024 | 1024 | 1522 | 0 | 0 |
| 4 | 1024 | 1024 | 1522 | 0 | 0 |

Per-profile deterministic counts and aggregate mass publications are identical
across worker counts.

Observed real physical concurrency:

- 1 worker: max simultaneous = 1;
- 2 workers: max simultaneous = 2;
- 4 workers: max simultaneous = 4.

Thus the in-process runtime is genuinely concurrent rather than silently
serializing the work.

## Per-profile retry authority

- 9024010 / Hn21: 557 retries;
- 8060 / zEZ21: 414 retries;
- 9024090 / cHn21: 281 retries;
- 90210030 / pZg23: 270 retries.

Total:
`1522`.

This exactly matches ELASTIC71.

## Timing

Shared-CI timing around only the in-process worker-pool calls:

| workers | summed profile-batch seconds | throughput columns/s | speedup vs 1 worker |
| ---: | ---: | ---: | ---: |
| 1 | 0.035552818 | 28,802.2 | 1.000 |
| 2 | 0.037150189 | 27,563.8 | 0.957 |
| 4 | 0.050420359 | 20,309.3 | 0.705 |

For this 1024-column population:

- 2 workers are about 4.3% slower than 1 worker;
- 4 workers are about 41.8% slower than 1 worker.

The worker pool therefore preserves semantics but does not provide positive
throughput scaling at this small/cheap workload.

## Interpretation

This is not a failure of MULTI06 correctness.

The physical work per column has already been strongly reduced by the admitted
0.20-cm temporal budget. At this workload the remaining solve cost is small
enough that OpenMP scheduling, barriers and worker-local orchestration dominate
the incremental benefit of additional workers.

The result is consistent with ELASTIC71, where process-based 0.20-cm execution
also stopped scaling beyond a small worker count.

The practical implication is important:

> After reducing per-column solve work, more workers are not automatically
> faster. Worker count must be chosen from workload size and solve cost rather
> than treated as a fixed performance multiplier.

## Geometry boundary

MULTI07 does not change the compile-time MOD_grid ownership boundary.

The four BOFEK profiles remain separate profile-specific runtime batches.
Heterogeneous geometry inside one runtime registry is not qualified.

## Decision

Semantic classification:

`QUALIFIED_MODE7_GENERATED_INPROCESS_POPULATION_PERFORMANCE`.

Performance classification:

`QUALIFIED_NEGATIVE_SMALL_POPULATION_WORKER_SCALING_RESULT`.

The admitted MULTI06 route is correct and deterministic, but the tested
1024-column population does not justify using more than one in-process worker
for performance.

No production code change follows from this result.

## Next-step boundary

Do not optimize the temporal budget further.

Do not change worker semantics merely to force a positive scaling result.

A future worker-performance study is justified only for substantially larger
populations and/or more expensive physical process combinations, with worker
count treated as an application-level scheduling choice.
