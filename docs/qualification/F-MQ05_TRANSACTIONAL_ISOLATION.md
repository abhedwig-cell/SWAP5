# F-MQ05 Transactional isolation testdouble

Status: `PASS_TESTDOUBLE_TRANSACTIONAL_ISOLATION / PRODUCTION_RUNTIME_STILL_INTERFACE_NEEDED`

## Scope

F-MQ05 extends the existing F-MQ02 deterministic test harness with only the transaction semantics needed to falsify MultiSWAP isolation defects cheaply. It does not introduce a production scheduler, production worker runtime or real SWAP physics.

All new implementation is under `tests/multiswap/`. No `src/` file is changed.

## Reuse rather than duplication

`transactional_isolation_harness.py` imports the F-MQ02 definitions for:

- logical column specification and state;
- template grouping;
- batch creation;
- queue ordering;
- worker-owned scratch;
- state cloning.

F-MQ05 adds only:

- trial candidates that are never committed directly;
- one-shot retry injection;
- terminal failure injection;
- rollback accounting;
- retry requeueing behind other logical columns;
- committed-only synthetic mass accounting;
- per-column transaction routes and exact integer counters.

The semantics are consistent with the A23BL/A23BU qualified historical patterns, but the old production representation is not copied into F-MQ.

## Properties exercised

### P07 rollback isolation

A terminally failed column produces a trial candidate but commits nothing. Its committed state remains equal to its checkpoint. Other columns remain identical to the all-success baseline.

### P08 retry isolation

A selected column rejects its first trial and is requeued. The retry starts from the original committed checkpoint, not from the rejected candidate. The final endpoint and committed mass equal the no-retry reference, while only that column receives retry/rollback counters.

### P18 interleaving

A 17-column case with three retrying columns is interleaved over four logical workers. Retries are appended to the queue, so other columns execute between first trial and retry. Every interleaved per-column semantic result is compared with an independently executed one-column reference.

### P19 scratch poisoning

Different worker scratch poison patterns and seeds produce the same canonical committed result hash, including cases with interleaved retries.

### Additional partition stress

The gate also exercises:

- 31 columns under different orderings, batch sizes and worker counts with retries;
- 32 columns with three retrying and two terminally failing columns;
- template-batched versus single-column execution for the same retrying target;
- fail-closed validation of invalid retry/failure sets.

The use of 17, 31 and 32 columns is deliberate because these sizes expose nontrivial partition and queue-boundary errors more efficiently than a large homogeneous count.

## Synthetic committed mass rule

The testdouble uses exact integer water accounting. Rejected trials may calculate a candidate and trial fluxes, but those trial fluxes never enter committed accounting. A retrying column therefore has two attempts but exactly one committed interval contribution.

This is a transaction invariant test, not a scientific water-balance oracle. Real SWAP hard-mass qualification remains blocked on the F-CI/F-KT physical continuation seam identified by F-MQ04d.

## Gate evidence

Repository command:

`python3 tests/multiswap/run_fmq05_gate.py`

Construction-time execution of the same harness/test content produced:

- tests: 9;
- failures: 0;
- errors: 0.

This is local construction evidence, not a GitHub Actions CI claim.

## Qualification boundary

F-MQ05 makes the **testdouble portions** of P07, P08, P13, P18 and P19 executable and strengthens the existing P02/P03/P04 isolation evidence under retry/interleaving conditions.

It does not claim:

- real concurrent threads executed safely;
- a production F-MR scheduler exists;
- real SWAP rollback/retry isolation is qualified;
- real SWAP mass conservation is qualified;
- worker-count or batch independence of the future production runtime is already proven.

Those claims remain `INTERFACE_NEEDED` until F-MR and the real F-CI/F-KT physical seam are available.

## Architecture assessment

F-MQ05 directly supports invariants 5, 6, 7, 8, 13, 16, 23, 24, 26 and 30. It preserves the hard boundary that qualification infrastructure may expose missing production seams but may not modify production code to make a test pass.
