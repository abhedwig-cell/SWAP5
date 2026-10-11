# F-PE-MULTI01 — current-canonical MultiSWAP scaling rebaseline

Date: 2026-09-27

Status: `PREREGISTERED_OBSERVATION_ONLY`

Canonical authority at start:
`integration/f-ci-canonical@c79ea4d7efb580eeb55b61a4e93b4bc6f01bfc96`

Branch:
`work/f-pe-multi01-current-canonical-scaling`

## Trigger

The single-column exact-performance line has reached diminishing returns.

Recent evidence:

- LIVE01: unavoidable live exact q/state trials are the primary remaining SWAP-side cost;
- BASE01 P0: about 83% of exact trial time sits in the serialized Reference backend;
- BASE01 P1/P1B: no isolated HeadCalc family produces a sufficiently large exact-preserving successor; temporal-indicator work is the only measured >20% backend family;
- BASE01 P2: exact-preserving temporal demand specialization preserves semantics but produces only about 0.6% backend gain and no total-trial gain;
- HYDTABLE01: a much faster isolated conductivity kernel does not improve full Richards solver wall clock.

Therefore the next performance question moves from one-column kernel shaving to large-N execution.

## Primary question

For 1,000 to 10,000 independent SWAP columns, where does wall-clock scaling go on current canonical, and how much of the available parallel worker-pool capacity survives end-to-end runtime overhead?

## Existing capability

Current canonical already contains:

- `mod_fmr_parallel_physical_scheduler`;
- `mod_fmr_parallel_worker_pool`;
- worker-owned heavy Reference backends and transaction controls;
- admitted 2-worker and 4-worker execution for a bounded physical profile;
- deterministic canonical publication after parallel execution.

MULTI01 does not invent a second scheduler before measuring the existing one.

## Hard boundary

MULTI01 is observation-only.

No production `src/**` changes.

Any batching, scheduler, data-layout, worker-pool or coupling change requires a separately preregistered follow-up.

## P0 scaling matrix

Measure the existing qualified parallel profile at minimum for:

- N = 100;
- N = 1,000;
- N = 10,000.

Worker counts:

- 1;
- 2;
- 4.

Batch sizes should include at least:

- 1;
- a moderate batch;
- a large batch that amortizes synchronization.

All compared arms must execute the same logical columns, physical inputs and accepted interval.

## Required outputs

For every configuration report:

- total repeated wall clock;
- ns/column;
- throughput columns/s;
- speedup versus worker_count=1;
- parallel efficiency = speedup / worker_count;
- number requested/admitted/executed/committed;
- physical solve count;
- max simultaneous real physical solves;
- aggregate attempts/retries;
- deterministic publication status;
- aggregate mass authority;
- worker work distribution;
- batch count.

Where feasible also report:

- setup time separately from repeated execution;
- worker busy-time imbalance;
- scheduling/publication overhead;
- peak RSS and per-column persistent-state scaling.

## P0 correctness gate

Parallel performance evidence is valid only when:

- worker_count 1/2/4 preserve accepted physical outputs;
- aggregate mass remains complete;
- canonical publication order is preserved;
- no unsupported profile is silently admitted;
- max simultaneous physical solves demonstrates real concurrency for multiworker arms;
- OMP team size matches the requested admitted worker count.

## Decision targets

P0 must distinguish among:

1. **GOOD_SCALING**
   Existing worker-pool parallelism already gives useful large-N speedup. Next work should focus on extending the qualified profile and/or coupling integration rather than rewriting the scheduler.

2. **SYNC_OR_BATCH_OVERHEAD**
   Physical work parallelizes, but barriers/batch sizing dominate. Open a batching/scheduling follow-up.

3. **DISPATCH_OR_PUBLICATION_OVERHEAD**
   Worker compute scales but orchestration or canonical collection dominates. Open a runtime-overhead follow-up.

4. **LOAD_IMBALANCE**
   Difficult columns dominate makespan. Open a load-balancing/scheduling follow-up using measured tail distributions.

5. **NO_MEANINGFUL_PARALLEL_GAIN**
   Existing parallel route does not improve the relevant large-N workload. Diagnose before any expansion.

## Non-targets

MULTI01 does not:

- change Richards equations;
- retune c=0.65;
- reopen HYDTABLE01;
- reopen BASE01 P2;
- change A2C;
- change MODFLOW equations;
- introduce GPU execution;
- claim national-scale speedup from a small-N test.

## Closure

MULTI01 closes with a current-canonical large-N scaling map and exactly one immediate successor target, or with a documented result that the existing parallel route is already sufficient for the bounded profile.
