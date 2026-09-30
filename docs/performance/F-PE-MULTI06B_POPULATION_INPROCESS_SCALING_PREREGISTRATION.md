# F-PE-MULTI06B — source-weighted population in-process scaling

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH

Baseline:
`integration/f-ci-canonical@84f4861c4a21e942d2e4954004a05fab39f31083`

Parent admission:
F-PE-MULTI06.

Reference population authority:
F-PE-ELASTIC71.

## Purpose

Repeat the frozen 1024-column ELASTIC71 source-weighted GENERATED-ELAS mode-7
population through the newly admitted in-process worker pool.

This is runtime performance characterization only.

## Frozen population

Reuse exactly the ELASTIC71 source-driven selection and allocation:

- profile 9024010 / Hn21: 363 columns;
- profile 8060 / zEZ21: 292 columns;
- profile 9024090 / cHn21: 202 columns;
- profile 90210030 / pZg23: 167 columns.

Within each profile, cycle the same sixteen combinations:

- h0 = -75, -20, +2, +10 cm;
- top-flux perturbation = -0.05, -0.035, +0.035, +0.05 cm/day.

Policy:
`0.20 cm`.

## Geometry ownership

Each BOFEK profile is compiled and executed as its own geometry-specific batch.

The four profile batches are executed sequentially for a given worker count.

Within each profile batch, columns execute through
`fmr_run_parallel_physical_multiswap` with the admitted MULTI06 worker-pool
profile.

This does not claim heterogeneous geometry within one in-process registry.

## Worker counts

Evaluate exactly:

- 1 worker;
- 2 workers;
- 4 workers.

Every worker-count run rebuilds fresh committed states before execution.

## Deterministic gates

Aggregate across the four profile batches.

Require for every worker count:

- requested columns = 1024;
- completed = 1024;
- committed = 1024;
- total retries = 1522;
- mass failures = 0;
- solver/dispatch rejections = 0.

These values are frozen from the qualified ELASTIC71 0.20-cm population result.

Within each profile batch, worker-count 2 and 4 must be per-column semantically
identical to worker-count 1 for completion, commit revision, retries and mass
publication.

Aggregate deterministic counts must be identical for 1, 2 and 4 workers.

## Timing

Measure wall time for the complete four-batch population, excluding profile
preparation and compilation.

Report:

- total seconds;
- throughput columns/s;
- speedup relative to worker_count=1.

Timing is descriptive on shared CI hardware and is not a universal MultiSWAP
speed claim.

## Decision

Qualify the in-process population runtime if all deterministic gates pass.

Worker scaling may be positive, neutral or overhead-limited without affecting
semantic admission.

No temporal-budget calibration, physics change or additional policy widening is
allowed in this workunit.
