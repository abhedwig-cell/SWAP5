# F-PE-MULTI07 — in-process mode-7 population performance

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH

Baseline:
`integration/f-ci-canonical@84f4861c4a21e942d2e4954004a05fab39f31083`

Parent authority:
- F-PE-ELASTIC71 population-level GENERATED mode-7 performance confirmation;
- F-PE-MULTI06 canonical admission of GENERATED ELAS + mode-7 + temporal-history in the generic in-process worker pool.

## Purpose

Repeat the frozen ELASTIC71 1024-column source-weighted population through the
canonically admitted in-process physical worker pool.

This workunit measures runtime behavior only. It does not broaden the 0.20 cm
policy and does not reopen temporal-budget calibration.

## Frozen population

Reuse exactly the ELASTIC71 source-selection rule and resulting allocation:

- profile 9024010 / Hn21: 363 columns;
- profile 8060 / zEZ21: 292 columns;
- profile 9024090 / cHn21: 202 columns;
- profile 90210030 / pZg23: 167 columns.

Total:
`1024` logical columns.

Within each profile batch, cycle deterministically over the same sixteen cases:

- h0 = -75, -20, +2, +10 cm;
- forcing delta = -0.05, -0.035, +0.035, +0.05 cm/day.

Use:

- GENERATED ELAS;
- bottom_mode = 7;
- swkimpl = 0;
- RICHARDS_TEMPORAL_HISTORY;
- explicit caller-owned temporal head budget = 0.20 cm;
- initial attempted interval = 0.015625 day;
- max retries = 8.

## Geometry boundary

The legacy Richards closure still owns MOD_grid at compile time.

Therefore each of the four frozen profiles is executed as a separate
profile-specific executable and one in-process worker-pool invocation per
profile batch.

This workunit does not claim heterogeneous geometry inside one runtime registry.

## Worker counts

Measure exactly:

- 1 worker;
- 2 workers;
- 4 workers.

For each worker count execute all four profile batches and aggregate:

- completed columns;
- committed columns;
- transaction retries;
- temporal rejections;
- mass failures;
- solver failures;
- aggregate mass completeness;
- wall time;
- throughput.

## Frozen deterministic authority

The admitted 0.20-cm ELASTIC71 population produced:

- completed = 1024;
- retries = 1522;
- temporal rejections = 1522;
- mass rejections = 0;
- solver rejections = 0.

MULTI07 must reproduce those aggregate deterministic counts for worker counts
1, 2 and 4.

## Qualification gates

Require:

1. every profile batch dispatches successfully for all worker counts;
2. total completed = 1024 and total committed = 1024;
3. total retries = 1522 for each worker count;
4. total temporal rejections = 1522 for each worker count;
5. mass failures = 0;
6. solver failures = 0;
7. aggregate mass is complete for every profile batch;
8. per-profile deterministic counts are identical across worker counts;
9. worker_count >1 demonstrates real physical concurrency >=2 in at least one
   profile batch;
10. production source delta = empty.

## Timing interpretation

Timing on shared CI is descriptive only.

Report:

- total wall time across the four profile batches;
- throughput columns/s;
- speedup of 2 and 4 workers relative to 1 worker.

Do not treat one shared-CI result as a universal MultiSWAP speedup.

## Decision

If all deterministic gates pass, classify:

`QUALIFIED_MODE7_GENERATED_INPROCESS_POPULATION_PERFORMANCE`.

If deterministic counts differ from ELASTIC71, stop and attribute the semantic
difference before any production change.

No additional temporal-budget research is allowed from this workunit.
