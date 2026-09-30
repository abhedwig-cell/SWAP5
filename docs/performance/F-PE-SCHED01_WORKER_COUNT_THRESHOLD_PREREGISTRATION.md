# F-PE-SCHED01 — workload-aware mode-7 worker-count threshold

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH

Baseline:
`integration/f-ci-canonical@a9bf62afd08b30087c3385709f94e4143d9de006`

Parent authority:
- F-PE-MULTI06 canonical in-process worker-pool admission;
- F-PE-MULTI07 qualified negative small-population worker-scaling result.

## Purpose

Determine a bounded workload-size threshold for choosing 1, 2 or 4 in-process
workers for the already admitted GENERATED ELAS + mode-7 + temporal-history
profile.

This workunit does not change physics, temporal budget, worker-pool semantics,
hard mass, solver tolerances or the existing scheduler.

## Frozen physical profile

Use the exact F-PE-MULTI06 / profile-8016 authority:

- BOFEK/BRO profile 8016 / EZg21;
- exact 16-node geometry;
- exact Staringreeks retention;
- GENERATED ELAS;
- bottom_mode = 7;
- swkimpl = 0;
- RICHARDS_TEMPORAL_HISTORY;
- explicit caller-owned temporal head budget = 0.20 cm;
- initial interval = 0.015625 day;
- max retries = 8.

Within each population, cycle over the same 16 state/forcing combinations:

- h0 = -75, -20, +2, +10 cm;
- forcing delta = -0.05, -0.035, +0.035, +0.05 cm/day.

## Population sizes

Evaluate exactly:

- N = 256;
- N = 1024;
- N = 4096;
- N = 16384.

For every N, evaluate exactly:

- 1 worker;
- 2 workers;
- 4 workers.

## Correctness gates

For every N and worker count:

1. every column completes and commits exactly once;
2. deterministic retry count is identical across worker counts at fixed N;
3. mass failures = 0;
4. rejected columns = 0;
5. aggregate mass publication is complete;
6. multiworker runs demonstrate real physical concurrency;
7. production source delta = empty.

## Timing protocol

For each N and worker count, run the in-process pool 5 times from a fresh
equivalent committed-state registry and use the median wall time.

Timing starts immediately before the worker-pool call and stops immediately
after it returns. Profile preparation, compilation and process startup are
excluded.

## Worker-selection rule

For each N, define the measured winner as the smallest worker count whose median
time is within 5% of the minimum median time across 1/2/4 workers.

The 5% band deliberately avoids selecting more workers for negligible timing
differences.

## Candidate threshold model

Only if the measured winners are monotone with N, fit the simplest step policy:

- 1 worker below threshold T12;
- 2 workers from T12 up to T24;
- 4 workers from T24 upward.

Thresholds must lie halfway in log2-space between adjacent tested N values
whose selected worker count differs.

If the measured winners are non-monotone, do not fit a threshold policy. Close
with a negative result and retain explicit worker count.

## Scope

Any resulting threshold is bounded to this admitted profile class and current
CI/runtime implementation. It is not yet a universal MultiSWAP worker policy.

A later SCHED02 may generalize using an immutable cost proxy if SCHED01 shows
that a stable size threshold exists.
