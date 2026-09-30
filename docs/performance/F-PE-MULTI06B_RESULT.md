# F-PE-MULTI06B — source-weighted population in-process scaling result

Date: 2026-09-30

Status: QUALIFIED_INPROCESS_POPULATION_SCALING_RESULT

Branch:
`research/f-pe-multi06b-population-inprocess-scaling`

Qualified postimage:
`6776dbfde56b797b2781c96a4dc7e1fca89351d1`

Canonical baseline:
`integration/f-ci-canonical@84f4861c4a21e942d2e4954004a05fab39f31083`

Workflow run:
`36755590559`

Job:
`110024889348`

Conclusion:
SUCCESS.

## Purpose

Repeat the frozen ELASTIC71 source-weighted 1024-column GENERATED-ELAS
mode-7 population through the canonically admitted MULTI06 in-process
worker pool.

No production source was changed by this workunit.

## Frozen population

Exactly the ELASTIC71 population was reused:

| profile | soil unit | columns |
| --- | --- | ---: |
| 9024010 | Hn21 | 363 |
| 8060 | zEZ21 | 292 |
| 9024090 | cHn21 | 202 |
| 90210030 | pZg23 | 167 |

Total:
`1024` columns.

Each profile retained its own exact frozen geometry, retention and GENERATED
elastic-storage parameterization. Because MOD_grid geometry remains
compile-time/global in the legacy Richards closure, the four profiles were
executed as four sequential geometry-specific batches. Within each batch,
columns executed through `fmr_run_parallel_physical_multiswap`.

Policy:
`0.20 cm`.

## Deterministic result

For all worker counts:

| workers | requested | completed | committed | retries | mass failures | rejected |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1024 | 1024 | 1024 | 1522 | 0 | 0 |
| 2 | 1024 | 1024 | 1024 | 1522 | 0 | 0 |
| 4 | 1024 | 1024 | 1024 | 1522 | 0 | 0 |

The exact frozen ELASTIC71 0.20-cm population authority is reproduced:

- completed = 1024/1024;
- retries = 1522;
- mass failures = 0;
- dispatch/column rejections = 0.

Per-column outputs are identical across worker counts after removing only the
worker-count label.

Observed real physical concurrency:

- 1 worker: 1;
- 2 workers: 2;
- 4 workers: 4.

Thus the worker-count result is not a serial fallback.

## Timing

Timing excludes source preparation and compilation and covers the four
profile-specific in-process batches together.

| workers | wall time s | throughput columns/s |
| ---: | ---: | ---: |
| 1 | 0.380916 | 2,688 |
| 2 | 0.056234 | 18,210 |
| 4 | 0.058403 | 17,533 |

The raw ratios relative to the one-worker observation are approximately:

- 2 workers: 6.77x;
- 4 workers: 6.52x.

These ratios are not treated as portable worker scaling. The one-worker
measurement includes the serialized delegation path and appears strongly
affected by cold-start / short-run overhead on shared CI. The robust timing
observation is narrower:

- two-worker in-process execution is materially faster than the one-worker
  observation in this benchmark;
- four workers does not improve on two workers for this small 1024-column
  workload;
- 2-worker and 4-worker throughput are of the same order, with 2 workers about
  4% faster in this run.

No admission decision depends on these wall-time ratios.

## Semantic interpretation

MULTI06B confirms that the performance benefit established in ELASTIC71 is
compatible with the real admitted in-process worker runtime:

`GENERATED ELAS + mode7 + 0.20 cm`
-> exact ELASTIC71 population semantics
-> worker-local in-process execution
-> identical committed/mass result at worker counts 1, 2 and 4.

The result therefore removes the main uncertainty left by the ELASTIC71
process-based worker experiment: the bounded mode-7 policy works through the
actual in-process worker pool without semantic drift.

## Geometry boundary

This workunit does not remove the current heterogeneous-geometry limitation.

Different BOFEK geometries still require separate profile batches because the
legacy Richards closure owns MOD_grid at compile time.

That limitation is now independent of the temporal-budget and worker-pool
questions.

## Decision

Classification:

`QUALIFIED_GENERATED_MODE7_INPROCESS_POPULATION_RUNTIME`.

MULTI06/MULTI06B establish the bounded in-process runtime route for
GENERATED ELAS mode-7 columns sharing one compiled geometry, and show that the
source-weighted ELASTIC71 population can be executed as deterministic
profile-specific parallel batches.

## Closure direction

No additional temporal-budget research or worker-pool admission widening is
required.

A future heterogeneous-geometry runtime refactor, if wanted, is a separate
architecture/performance workstream rather than a continuation of the ELAS
temporal-budget line.
