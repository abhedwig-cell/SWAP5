# F-PE-MULTIPROC01 — process versus thread parallelism

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Canonical parent:
`integration/f-ci-canonical@4ee57d17a3793a58c792d5de9cdd0a38f9e7918a`

Parent performance authority:
`F-PE-MULTI04 / PR #666`

Branch:
`work/f-pe-multiproc01-process-vs-thread`

## Purpose

Test whether the same total MultiSWAP groundwater workload executes more efficiently as:
- one process with four workers;
- two independent processes with two workers each;
- four independent processes with one worker each.

The experiment uses the same total logical column population and the same 4-logical-CPU GitHub host.

## Research question

Does coarse process-level partitioning reduce OpenMP/runtime contention, synchronization, allocator or cache interference enough to improve total throughput relative to one 4-worker process?

## Frozen configurations

At total population N:

1. `1x4`
   - 1 process;
   - N columns;
   - 4 workers.

2. `2x2`
   - 2 concurrent processes;
   - N/2 columns per process;
   - 2 workers per process.

3. `4x1`
   - 4 concurrent processes;
   - N/4 columns per process;
   - 1 worker per process.

Primary N:
- 10,000.

Follow-up N:
- 40,000 if P0 is stable and runtime remains practical.

N must be divisible by 4.

## Production boundary

No production source change is authorized.

All worker counts are already inside the MULTI04 production-admitted set:
- 1;
- 2;
- 4.

Each process owns its own complete application context and mutable backend state. No state is shared across OS processes.

## Measurement

For each configuration:
- one unmeasured warm-up per process;
- 5 replicated measured rounds;
- each round launches all processes in the configuration concurrently;
- measure wall-clock from launch until the final process completes;
- report total throughput in columns/s;
- report speed relative to `1x4`;
- report aggregate q and tangent checksums.

Compilation/setup time is excluded from the measured interval.

## Semantic gate

Aggregate q and tangent checksums must match the `1x4` authority within a strict floating-point summation tolerance consistent with independent process aggregation.

Per-process repeated output must be deterministic.

Any process failure invalidates the configuration.

## Performance interpretation

Use median wall-clock across replicated rounds.

Classify relative to `1x4`:
- `PROCESS_WIN`: >=5% faster;
- `EQUIVALENT`: within +/-5%;
- `THREAD_WIN`: >=5% slower.

Do not tune process/thread counts after observing results inside this workunit.

## Successor rule

If `2x2` or `4x1` wins by >=5%, open a follow-up to identify whether the gain comes from:
- OpenMP overhead;
- cache/NUMA locality;
- allocator/runtime isolation;
- scheduling granularity.

If all configurations are equivalent, retain one-process worker-local execution as the simpler production architecture.

If `1x4` wins, close process partitioning as a performance route for the current host.

## Scope limitation

This experiment is about throughput on one 4-logical-CPU host. It does not determine the optimal process/thread decomposition on a future 24-thread machine, but it establishes whether process isolation is promising enough to carry forward.
