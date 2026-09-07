# F-MQ09 Single-column versus MultiSWAP equivalence

Status: `PASS_SYNTHETIC_P01 / REAL_AND_PRODUCTION_EQUIVALENCE_OPEN`

## Scope

F-MQ09 closes the cheap synthetic part of qualification property P01: the same logical column executed directly through the deterministic qualification kernel must produce exactly the same semantic result when executed through the MultiSWAP qualification harness.

This work unit changes qualification infrastructure only. It does not change the SWAP kernel, solver physics, numerical policy or production MultiSWAP runtime.

## Why this is a separate gate

F-MQ02 already showed that the synthetic MultiSWAP harness is deterministic under batching, workers and ordering. It did not explicitly compare the harness result against a direct standalone call to the same kernel. P01 requires that equivalence rather than only internal runtime determinism.

F-MQ09 therefore uses two paths to one test kernel:

1. standalone path: direct `DeterministicTestKernel.advance(...)`;
2. MultiSWAP path: `run_multiswap(...)`, which dispatches the same `ColumnSpec` and `ColumnState` through template grouping, batching and worker scratch.

There is deliberately no second synthetic physics implementation.

## Exact comparison

For the target column, the gate compares exactly:

- terminal status;
- committed endpoint state;
- deterministic integer counters;
- synthetic committed water accounting.

Worker and batch attribution are scheduling metadata and are not treated as physical semantics. The test deliberately exercises configurations in which that attribution changes while the semantic result remains identical.

## Scenarios

`tests/multiswap/test_single_vs_multiswap_equivalence.py` contains four qualification tests:

1. direct standalone versus a one-column MultiSWAP run;
2. the same target column embedded among sixteen neighbours, across batch sizes 1, 3, 5, 8 and 17, worker counts 1 to 8, forward/reverse/seeded ordering and scratch poisoning;
3. strongly changed neighbour physics signatures and synthetic forcing rates cannot alter the target result;
4. worker/batch attribution is allowed to change while the target semantic result remains exactly equal to standalone.

The target starts from a nonzero continuation cursor and the interval is not tied to a day or midnight boundary.

## Coverage history

F-MQ08 remains an immutable coverage snapshot. F-MQ09 does not rewrite it.

`tests/multiswap/qualification_coverage_delta_fmq09.json` pins the exact F-MQ08 coverage blob and records only the P01 transition:

`WAITING_CANONICAL_PHYSICS_AND_FMR -> SYNTHETIC_EXECUTABLE_WAITING_REAL_AND_FMR`

The effective synthetic coverage therefore changes from 26 to 27 of the 35 F-MQ01 requirements. Real-physics executable remains 0 and production-runtime qualified remains 0.

## Construction evidence

The P01 logic was exercised during construction against the same deterministic kernel equations and scheduling semantics, including the multi-configuration 17-column case. The checked semantic comparisons passed.

The repository gate is:

`python3 tests/multiswap/run_fmq09_gate.py`

It includes both the P01 equivalence tests and the coverage-delta consistency tests. No GitHub Actions or full checked-out repository run is claimed here.

## What F-MQ09 does not claim

F-MQ09 does not establish:

- B1.10 or SWAP5 scientific equivalence between standalone and MultiSWAP;
- hard real-water mass qualification;
- production scheduler correctness or thread safety;
- production template/batch equivalence;
- any physical fixture qualification.

Those claims still require the canonical physical continuation/mass seam and the production F-MR runtime.

## Architectural assessment

F-MQ09 directly reinforces invariants 1, 3, 5, 6, 16, 23, 29 and 30. It is especially important for invariant 1: standalone and MultiSWAP must use one computational kernel rather than divergent model implementations.

The next F-MQ work should not manufacture further synthetic substitutes for missing production seams. The highest-value next action is to reassess the canonical F-CI line for a newly materialized generic B1.10 physical continuation and unrounded accepted mass path. If those are still incomplete, the remaining real-physics F-MQ properties should stay blocked rather than being simulated away.
