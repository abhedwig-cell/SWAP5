# SWAP5 performance goal and decision policy — 2026-09-30

Status: PROPOSED_CANONICAL_ROADMAP

Baseline:
`integration/f-ci-canonical@e5d2902be8ddd9261fdb44935244204ef60dbca6`

## Purpose

Consolidate the current performance evidence into one operational goal for
SWAP5/MultiSWAP development.

This note is a roadmap/decision-policy document. It does not itself admit a
new numerical mode or production implementation.

## Performance objective

The performance objective is not:

> maximize worker count or obtain linear speedup with thread count.

The performance objective is:

> minimize physically necessary computational work per accepted SWAP column,
> while preserving hard mass and application-relevant accuracy, and use
> parallel workers only when the remaining workload is large enough for their
> overhead to pay back.

## Evidence now established

### 1. Reduce solve work before adding workers

The mode-7 GENERATED ELAS temporal-budget line established that the deliberately
strict 0.01 cm research benchmark was not an appropriate application default.

The admitted bounded application policy is:

`GENERATED ELAS + bottom_mode=7 + swkimpl=0 + temporal head budget=0.20 cm`.

On the frozen source-weighted 1024-column population, the practical policy
reduced retries from 22,878 to 1,522 while preserving:

- full completion;
- hard mass;
- solver acceptance;
- bounded application diagnostics.

Therefore solve-work reduction can dominate the performance benefit of adding
workers.

### 2. Parallelism is workload dependent

MULTI06 established correct deterministic in-process mode-7 parallel execution.

MULTI07 then showed that the frozen 1024-column cheap workload was fastest with
one in-process worker even though real 2- and 4-worker physical concurrency was
observed.

Therefore:

- more workers are not automatically faster;
- worker count is runtime/application policy;
- worker count must not be hard-coded from available CPU count alone.

### 3. Column count alone is not a sufficient worker selector

SCHED01 tested population size as the worker-count predictor.

On the more expensive pZg23/profile-8016 class, 2 workers were already
preferred at N=256 and remained preferred through N=16,384.

MULTI07 had shown cheaper batches of comparable size preferring 1 worker.

Therefore:

`worker_count = f(N)`

is falsified as a general policy.

The relevant abstraction must include predicted per-column work.

### 4. Lagged committed work is plausible but not yet admitted

SCHED02 tested committed previous-interval solver work as a pre-trial worker
selector input.

The scheduling concept itself was not rejected, but the preregistered five-soil
calibration domain was blocked by a second-interval pZg23 numerical failure.

The PZG23-01..06 chain subsequently localized that failure to two wet
positive-forcing origins and established that it is a local nonlinear Richards
solvability blocker, not:

- worker/OpenMP behavior;
- hard mass;
- temporal-history ownership;
- max_iterations alone;
- max_backtracking alone;
- a single marginal convergence tolerance.

No automatic worker-count selector is therefore admitted yet.

### 5. High-core scaling requires real high-core hardware

MULTI05 already provides a frozen production-shaped high-core scaling harness.

On the available GitHub Actions host:

- 1 -> 2 workers scaled strongly;
- 4 workers still helped;
- 8/12/16/24 were oversubscribed and therefore not high-core evidence.

The repository already contains the manual self-hosted high-core execution
path.

Do not rerun high-core research on ordinary GitHub-hosted Actions and interpret
oversubscription as real scaling.

## Production-performance hierarchy

Future optimization should follow this order.

### A. Remove unnecessary physical solve work

Highest priority.

Examples:

- avoid unnecessary retries;
- remove redundant constitutive evaluations;
- reuse exact immutable/prepared data;
- remove repeated allocations/copies;
- use admitted practical accuracy policy where appropriate.

### B. Make each unavoidable solve cheaper

Examples:

- exact P0/P1 solver optimizations;
- qualified practical solver modes such as A2C where they reduce actual
  nonlinear work;
- derivative-consistent hydraulic acceleration.

Do not optimize arithmetic that is no longer a measured hotspot.

### C. Avoid unnecessary repeated solves

Only when transaction authority permits it.

PROFILE06 showed repeated Reference solves remain a major corrector cost.

APPROX04 showed that a local response surrogate may not bypass exact trials that
the exact participant itself rejects.

Therefore any future repeated-solve avoidance must remain inside the exact
transaction admissibility envelope and retain exact final validation before
commit.

### D. Parallelize the remaining work

Only after A-C.

Worker count must be selected from workload and predicted work, not from core
count alone.

For small/cheap batches, one worker can be optimal.

For large/expensive batches, use the qualified worker pool and measure scaling.

## Hard invariants

Performance work may not weaken:

- hard physical mass conservation;
- committed/candidate transaction ownership;
- rollback semantics;
- exact accepted-state publication;
- physical/numerical-policy separation;
- restart/lineage provenance;
- coupling ledger ownership.

A faster result that changes those contracts is not a performance
optimization.

## Accuracy policy

Research-oracle tolerances and application tolerances are separate.

Strict research envelopes remain valuable for qualification, but they must not
silently become production requirements.

Application accuracy policy must be:

- explicit;
- caller/application owned where appropriate;
- preregistered;
- validated on relevant physical outputs;
- bounded by hard mass independently.

## Benchmark policy

Use the cheapest evidence capable of answering the question.

Preferred order:

1. source/static analysis;
2. local/self-contained calculation;
3. existing frozen benchmark evidence;
4. local full-repository execution when available;
5. GitHub Actions only when repository qualification/integration requires it.

Do not use GitHub Actions as the default exploratory compute environment.

For high-core scaling, use a real high-core host. Never substitute oversubscribed
GitHub-hosted runners for real hardware evidence.

## Near-term roadmap

### Ready when high-core hardware is available

Run the existing frozen MULTI05 self-hosted harness unchanged:

- N=10,000 first;
- N=100,000 follow-up where practical;
- workers 1/2/4/8/12/16/24 up to visible hardware concurrency;
- exact q/tangent identity;
- replicated medians;
- explicit oversubscription classification.

### Before then

Do not open another worker-count tuning line merely to manufacture thresholds.

Use explicit worker count as application/runtime policy.

### Application-scale target

The next end-to-end performance authority should be a realistic regional
MultiSWAP workload with representative physical process mix.

Measure:

- total accepted-column throughput;
- retry distribution;
- solver-work distribution;
- worker utilization;
- wrapper/coupling overhead;
- MODFLOW/SWAP split where coupled;
- hard mass and publication correctness.

The purpose is to determine whether the remaining bottleneck is:

- Richards solve cost;
- optional process cost;
- coupling correctors;
- scheduling/load imbalance;
- memory/cache/bandwidth;
- or orchestration overhead.

## Stop rule for micro-optimization

Do not open a new micro-optimization workunit unless:

1. a current representative profile identifies the target as material;
2. the expected improvement is measurable on available hardware;
3. the change has a bounded ownership/physics surface;
4. there is a clear preservation gate.

The PZG23 localized solver edge case is closed unless it becomes a material
production reliability problem.

The APPROX04 local response-surrogate route remains rejected under the current
exact participant admissibility envelope.

## Target end state

A mature MultiSWAP runtime should:

- execute the minimum necessary physical work per column;
- use application-specific bounded numerical policy;
- keep hard mass independent;
- predict workload before execution from immutable/committed information;
- choose batching/worker count accordingly;
- retain exact fallback and explicit diagnostics;
- scale on real hardware when there is enough physical work to amortize
  parallel overhead.

This, rather than worker count itself, is the performance definition for
SWAP5.
