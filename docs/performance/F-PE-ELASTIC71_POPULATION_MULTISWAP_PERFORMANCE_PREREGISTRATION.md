# F-PE-ELASTIC71 — population-level GENERATED mode-7 MultiSWAP performance

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH

Baseline:
`integration/f-ci-canonical@38b78b3415cee0563eb19efa68b73a6082b3c899`

Parent:
F-PE-ELASTIC70 production-shaped transaction confirmation.

## Purpose

Measure how much of the deterministic retry reduction from the admitted 0.20 cm
GENERATED-ELAS mode-7 policy survives in a larger mixed-column population and
under multiple independent workers.

This is a performance characterization. It does not alter or re-admit the
0.20 cm policy.

## Population source

Use the same frozen BRO/BOFEK GeoPackage authority already admitted by the
ELASTIC application chain.

The frozen relation
`soilarea_normalsoilprofile(maparea_id, normalsoilprofile_id)`
contains 48,025 one-to-one maparea/profile associations.

Select exactly four profiles by this preregistered rule:

1. profile has 1..16 contiguous horizons;
2. every Staringreeks block is one of B01..B18 or O01..O18;
3. no peat type is present;
4. dry density is finite and positive;
5. organic matter, when present, is <=20%;
6. rank eligible profiles by descending count in
   `soilarea_normalsoilprofile`;
7. break equal counts by ascending profile id;
8. take the first four.

This makes the benchmark source-frequency-driven instead of manually selecting
difficult cases after observing performance.

## Population size and allocation

Total logical population:
`N = 1024`.

Allocate columns among the four selected profiles proportional to their frozen
maparea counts using largest-remainder allocation, with profile id as the tie
breaker.

Within each profile population, cycle deterministically over:

- h0 = -75, -20, +2, +10 cm;
- forcing delta = -0.05, -0.035, +0.035, +0.05 cm/day.

Thus each selected soil exercises both benign and difficult temporal states.

Initial attempted interval:
`0.015625 day`.

Maximum retries:
8.

## Compared policies

Exactly:

- 0.01 cm strict research benchmark;
- 0.20 cm admitted GENERATED application policy.

All physical parameters, generated Ss, retention, state, forcing, hard mass,
solver tolerances and transaction semantics remain identical between arms.

## Worker model

The current admitted OpenMP MultiSWAP worker executor is coupled to the
groundwater/bottom-mode-5 participant contract. Reusing it for mode 7 would
change the semantic route under test.

Therefore this workunit uses independent worker processes. Each worker owns its
own compiled profile-specific legacy/serialized execution context and processes
a deterministic shard of the population.

Evaluate:

- 1 worker;
- 2 workers;
- 4 workers.

No claim is made that process overhead equals the final in-process MultiSWAP
worker implementation. The worker experiment tests parallel independence and
coarse population scaling without assuming unqualified legacy thread safety.

## Primary deterministic metrics

For each policy across all 1024 columns:

- completed columns;
- total transaction retries;
- total temporal rejections;
- mass rejections;
- solver rejections;
- accepted-substep distribution.

Required correctness gates:

- 0.20 cm completion >= 0.01 cm completion;
- 0.20 cm retries <= 0.01 cm retries;
- hard mass behavior unchanged;
- solver rejection count may not increase;
- all GENERATED parameter materialization must pass;
- source delta relative to canonical must remain empty.

## Timing

For each policy and worker count record wall time for the same 1024-column
population.

Timing is descriptive on shared CI hardware. Report:

- policy ratio at each worker count;
- worker scaling within each policy;
- throughput columns/s.

Do not convert one CI run into a universal MultiSWAP speed claim.

## Decision

Qualify a population-level performance confirmation if:

1. the 0.20 cm arm has deterministic retry/work improvement or equal work with
   higher completion;
2. mass and solver gates remain green;
3. the mixed population completes reproducibly;
4. independent worker execution produces identical aggregate deterministic
   counts.

Otherwise retain ELASTIC69/70 authority and close this population benchmark as
negative or blocked without changing the policy.
