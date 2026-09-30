# F-PE-MULTI07 — post-qualification closure

Date: 2026-09-30

Status: CLOSED_INPROCESS_POPULATION_PERFORMANCE_CHARACTERIZED

Canonical baseline:
`integration/f-ci-canonical@84f4861c4a21e942d2e4954004a05fab39f31083`

Qualified research authority:
- branch: `research/f-pe-multi07-mode7-population-inprocess`;
- qualified postimage: `cd7ba6c02d5dc55781e58a2128bf21741451499c`;
- result document commit: `e4a5c09ee1495ca8aa6642d2ff4ee542b4f0f89b`;
- workflow run: `36755581238`;
- job: `110024854345`;
- conclusion: SUCCESS.

## Closed semantic claim

The canonically admitted MULTI06 in-process worker pool reproduces the frozen
ELASTIC71 GENERATED-ELAS mode-7 population authority exactly when the
heterogeneous BOFEK population is executed as four geometry-homogeneous
profile batches.

Across the frozen 1024 columns, worker counts 1, 2 and 4 all produce:

- completed = 1024;
- committed = 1024;
- retries = 1522;
- mass failures = 0;
- rejected columns = 0.

Per-profile retry counts and aggregate mass publications are identical across
worker counts.

Real physical concurrency is observed:

- 2-worker run: max simultaneous physical solves = 2;
- 4-worker run: max simultaneous physical solves = 4.

Classification:

`QUALIFIED_MODE7_GENERATED_INPROCESS_POPULATION_PERFORMANCE`.

## Closed performance result

The tested 1024-column population does not benefit from additional in-process
workers.

Shared-CI timing around the worker-pool calls:

- 1 worker: 0.035552818 s;
- 2 workers: 0.037150189 s;
- 4 workers: 0.050420359 s.

Corresponding speedup relative to 1 worker:

- 1 worker: 1.000;
- 2 workers: 0.957;
- 4 workers: 0.705.

Thus the bounded scaling result is negative:

`QUALIFIED_NEGATIVE_SMALL_POPULATION_WORKER_SCALING_RESULT`.

This does not invalidate MULTI06. It establishes that, after the admitted
0.20-cm temporal policy has removed most retry work, this small population is
too cheap for OpenMP worker overhead to pay back.

## Application implication

Worker count must remain an application scheduling decision rather than a
hard-coded expectation that more workers are faster.

For this bounded population, one in-process worker is the measured best choice.

Do not infer that one worker is optimal for:

- much larger populations;
- more expensive optional processes;
- macropore/root/snow/temperature combinations;
- future runtime-owned heterogeneous geometry;
- MODFLOW coupled mode-5 execution.

## Geometry boundary

The compile-time MOD_grid ownership remains unchanged.

The four BOFEK geometries are therefore executed as separate profile batches.
MULTI07 does not qualify heterogeneous geometry in one runtime registry.

## Closure

F-PE-MULTI07 is closed.

No additional temporal-budget tuning or worker-pool code change is justified by
this result.

Future scaling work should only reopen the question with a materially larger or
more expensive workload and should treat worker count as a workload-dependent
scheduling parameter.
