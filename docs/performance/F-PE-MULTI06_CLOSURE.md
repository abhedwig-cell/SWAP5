# F-PE-MULTI06 / MULTI06B — closeout

Date: 2026-09-30

Status: CLOSED_PRODUCTION_ADMITTED_AND_POPULATION_CONFIRMED

Canonical admission:
`integration/f-ci-canonical@84f4861c4a21e942d2e4954004a05fab39f31083`

Admission PR:
`#904 — F-PE-MULTI06: admit GENERATED mode7 temporal-history worker pool`

## Admitted runtime capability

The existing generic in-process physical MultiSWAP worker pool now admits the
bounded combination:

`GENERATED ELAS + bottom_mode=7 + swkimpl=0 + RICHARDS_TEMPORAL_HISTORY`

under the already admitted explicit caller-owned mode-7 head budget policy.

The production change is limited to the admission gate in:

`src/runtime/mod_fmr_parallel_worker_pool.f90`.

No new executor, scheduler, transaction loop, mass policy or solver policy was
introduced.

## MULTI06 qualification

Exact BOFEK/BRO profile 8016, 256 independent logical columns:

| workers | completed | committed | retries | mass failures | max simultaneous solves |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 256 | 256 | 368 | 0 | 1 |
| 2 | 256 | 256 | 368 | 0 | 2 |
| 4 | 256 | 256 | 368 | 0 | 3 |

Per-column outputs are identical across worker counts after removing only the
worker-count label.

Aggregate mass is complete and its residual is identical across worker counts:

`2.8773684823679702e-11`.

Qualified evidence:
- work head: `02eae81c707c60b777e0f26ca387da17e0a313c6`;
- workflow run: `36754571171`;
- job: `110021423315`;
- conclusion: SUCCESS.

## MULTI06B population confirmation

The frozen ELASTIC71 source-weighted population was repeated through the
canonically admitted in-process worker pool as four geometry-specific profile
batches.

Population:
- 9024010 / Hn21: 363 columns;
- 8060 / zEZ21: 292 columns;
- 9024090 / cHn21: 202 columns;
- 90210030 / pZg23: 167 columns;
- total: 1024 columns.

For worker counts 1, 2 and 4, the exact deterministic result is:

- requested: 1024;
- completed: 1024;
- committed: 1024;
- retries: 1522;
- mass failures: 0;
- rejected columns: 0.

Per-column results are identical across worker counts.

Observed real concurrency:
- 1 worker: 1;
- 2 workers: 2;
- 4 workers: 4.

Qualified MULTI06B evidence:
- branch: `research/f-pe-multi06b-population-inprocess-scaling`;
- qualified postimage: `6776dbfde56b797b2781c96a4dc7e1fca89351d1`;
- result document commit: `e0a0219ff072559ab98a1afa1eadd6e48373bd10`;
- workflow run: `36755590559`;
- job: `110024889348`;
- conclusion: SUCCESS.

## Timing observation

MULTI06B measured the four profile batches together, excluding source
preparation and compilation:

| workers | wall time s | throughput columns/s |
| ---: | ---: | ---: |
| 1 | 0.380916 | 2,688 |
| 2 | 0.056234 | 18,210 |
| 4 | 0.058403 | 17,533 |

These shared-CI timings are descriptive only.

The one-worker timing is strongly affected by the serialized delegation and
short-run/cold-start overhead. Therefore the raw apparent 6.5–6.8x ratio must
not be interpreted as portable worker scaling.

The robust practical observation is:

- in-process multiworker execution is semantically exact;
- two workers materially improve throughput in this benchmark;
- four workers provide no additional throughput over two workers for this
  small workload;
- no numerical, transaction or mass regression accompanies the parallel path.

## Preserved boundaries

Still unchanged and fail-closed outside this scope:

- swkimpl=1;
- temporal history without the qualified elastic-storage profile;
- KSATEXM with elastic storage;
- direct retention with elastic storage;
- tabulated hydraulics;
- hysteresis;
- root extraction;
- snow;
- macropores;
- frost;
- arbitrary optional-process combinations.

Hard physical mass acceptance, solver convergence tolerances, frozen mode-7
alpha and the explicit 0.20-cm application policy are unchanged.

## Heterogeneous geometry boundary

MULTI06 does not remove legacy MOD_grid ownership.

Different BOFEK vertical geometries still require separate geometry-specific
profile batches. The ELASTIC71 population is therefore executed as four
sequential profile batches, each internally parallel.

Removing this boundary is a separate runtime architecture task and is not
required to close the temporal-budget or worker-pool research line.

## Closure

F-PE-MULTI06 and F-PE-MULTI06B are closed.

Production status:

`PRODUCTION_ADMITTED_GENERATED_MODE7_INPROCESS_WORKER_POOL`.

Population status:

`QUALIFIED_GENERATED_MODE7_INPROCESS_POPULATION_RUNTIME`.

No further temporal-budget calibration or worker-pool admission widening is
required by this line.
