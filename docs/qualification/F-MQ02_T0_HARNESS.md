# F-MQ02 T0 deterministic MultiSWAP qualification harness

Status: `PASS_TEST_ONLY_T0_HARNESS / NO_PRODUCTION_RUNTIME_OR_PHYSICS_CHANGE`

## Scope

F-MQ02 turns the cheap MQ-T0 part of F-MQ01 into executable qualification infrastructure. All implementation lives under `tests/multiswap/`. No file under `src/` is changed and no SWAP kernel, solver physics, numerical policy or production MultiSWAP runtime is introduced or modified.

The harness is deliberately not a prototype production runtime. It is a falsification device for runtime contracts. Production integration still belongs to F-CI, F-KT, F-SI and later F-MR.

## Deterministic test kernel

`t0_harness.py` provides a tiny exact-arithmetic kernel with:

- stable logical column IDs;
- deterministic template classification from a physics signature;
- homogeneous batch partitioning;
- deterministic queue orderings: forward, reverse and seeded permutation;
- round-robin worker attribution;
- worker-owned reconstructible scratch that can be poisoned before execution;
- exact integer synthetic water accounting;
- explicit failure injection that leaves committed state unchanged;
- exact per-column, per-batch and run counters;
- canonical result serialization and SHA-256 replay hashes.

The kernel has no SWAP scientific meaning and may never be used as a physics oracle.

## Executable claims

The gate exercises all MQ-T0 runtime contracts R01-R08 from F-MQ01:

- R01 stable and unique column IDs;
- R02 deterministic physics-preserving template grouping;
- R03 exact batch cover without loss or duplication, including 17 columns;
- R04 one execution per scheduled job with explicit worker attribution;
- R05 queue/failure isolation;
- R06 execution-order independence;
- R07 exact diagnostic aggregation;
- R08 deterministic checkpoint replay over two intervals.

It also exercises testdouble portions of P02, P03, P04, P05, P06, P09, P12 and P15. These are not yet production MultiSWAP qualification claims. The final production claims remain dependent on the F-MR runtime seam and, where real water physics is required, the canonical F-CI/F-KT kernel interfaces and reference-derived fixtures.

## Gate evidence

Local qualification command:

`python3 tests/multiswap/run_t0_gate.py`

Observed during F-MQ02 construction:

- tests: 13
- failures: 0
- errors: 0
- elapsed: 0.009 s on the construction environment

Wall-clock time is informational only and is not a hard gate. The hard T0 criteria are exact states, hashes, integer counters, isolation and exact synthetic mass residuals.

## Important boundaries

F-MQ02 does not claim:

- production scheduler correctness;
- production thread safety;
- real SWAP mass conservation;
- scientific equivalence;
- B1.10 or SWAP5 physical fixture qualification;
- execution-class routing;
- tile aggregation;
- predictor/corrector rollback;
- coupling flux conservation;
- throughput or cache performance.

The F-MQ01 matrix remains the requirements matrix. Entries that require F-MR or a canonical real-kernel interface remain production-interface dependent even where their T0 primitive is now executable.

## Architecture check

F-MQ02 directly tests or supports invariants 3, 5, 6, 7, 8, 16, 23, 24, 26 and 30. It does not alter any physical or numerical behaviour.

## Next step

F-MQ03 should formalize event-local fixture serialization and canonical result comparison helpers, still outside production code. That allows short real-SWAP T1 tests to be plugged in later without turning long legacy cases into ordinary MultiSWAP unit tests.
