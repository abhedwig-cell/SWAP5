# F-MQ06 Difficult-column scheduling qualification

Status: `PASS_SYNTHETIC_DIFFICULT_COLUMN_SCHEDULING_REAL_PHYSICS_BLOCKED`

## Scope

F-MQ06 qualifies the synthetic difficult-column scheduling cases from the F-MQ01 matrix without changing SWAP production code, solver physics, numerical policy or a production MultiSWAP runtime.

The work unit deliberately reuses the F-MQ02 deterministic runtime primitives and the F-MQ05 transactional isolation harness. It does not create a second scheduler. The only new executable layer is a set of difficult-column scenarios and assertions.

## Qualified synthetic scenarios

### D01: 15 normal + 1 difficult

A 16-column batch contains fifteen normal columns and one retry-sensitive column. The difficult column rejects its first deterministic trial, rolls back, is requeued and then accepts.

The gate requires:

- all fifteen normal columns to remain exactly equal to the clean no-difficulty baseline;
- the difficult endpoint and committed synthetic mass to equal its clean accepted endpoint;
- exactly one additional attempt, kernel call, retry and rollback;
- zero additional commits or failures;
- all additional deterministic work counters to be attributable to the difficult column only;
- identical canonical outcome across worker counts, batch sizes, forward/reverse/seeded ordering and worker-scratch poison seeds.

### D02: 31 normal + 1 difficult

A 32-column batch exercises the same retry-sensitive case at a larger correctness scale and separately exercises a terminal difficult-column failure.

For the retry case, the same exact isolation and cost-attribution rules as D01 apply.

For terminal failure, the gate requires:

- all 31 normal columns to remain exactly equal to the clean baseline;
- the failed column to retain its original committed state;
- no rejected trial inflow/outflow to enter committed synthetic mass accounting;
- the failed column's committed storage start and end to remain equal;
- exactly one failure and 31 successful commits at run level;
- canonical results to remain independent of worker count, ordering, batching and scratch poison.

## Why this is not a performance claim

F-MQ06 uses deterministic operation counters, not elapsed wall-clock time. The purpose is to expose whether extra cost from one difficult column is bounded and attributable in the test model, and whether it contaminates other columns.

This does not qualify throughput, cache behaviour or production tail latency. Those remain in the performance lane and, for production runtime behaviour, later F-MR qualification.

## Why this is not yet B12 qualification

No B12/heavy-clay physical fixture is used here. The F-MQ01 D01/D02 real-SWAP side therefore remains blocked.

A real difficult-column qualification requires all of the following first:

1. a concrete canonical B1.10/SWAP5 physical continuation adapter from F-CI/F-KT;
2. complete unrounded accepted-interval mass accounting;
3. a qualified event-local difficult-column checkpoint produced through F-MQ04b and admitted by F-MQ04c;
4. a reference-mode result against which retries, fallback behaviour and deviations can be bounded;
5. a production MultiSWAP runtime seam from F-MR for actual scheduling/execution-class qualification.

F-MQ06 therefore does not invent a synthetic B12 oracle and does not turn a legacy long run into an every-commit test.

## Gate

Repository gate command:

`python3 tests/multiswap/run_fmq06_gate.py`

Construction-time execution of equivalent F-MQ02/F-MQ05 primitives plus the exact F-MQ06 scenario assertions produced:

- tests: 8;
- failures: 0;
- errors: 0.

This is local construction evidence, not a GitHub Actions CI claim.

## Matrix interpretation

F-MQ06 makes the **testdouble side** of D01 and D02 executable. It does not change the original matrix rows to fully executable because those rows also require real difficult-column physics. Their real-SWAP qualification stays blocked until a qualified event-local difficult fixture exists.

The work also strengthens synthetic evidence for P07, P08, P09, P15, P18 and P19 by combining rollback/retry/failure behaviour with larger 16- and 32-column schedules.

## Architecture invariants

F-MQ06 directly exercises or protects invariants 5, 7, 8, 13, 16, 24, 25, 26 and 30. In particular, invariant 24 is treated as an attribution and isolation requirement here, not as permission to weaken mass conservation or silently change physics.

## Next boundary

The next qualification work should remain production-independent unless F-CI has meanwhile exposed the missing physical continuation seam. Useful next targets are synthetic tile aggregation and coupling-transaction contracts (P20-P22), or a refresh of F-MQ04d when the canonical physical adapter becomes available.
