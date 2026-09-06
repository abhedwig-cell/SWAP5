# A23BL canonical always-sampled transaction reference contract

Baseline: `integration/a23bk-transactional-rebase` at `5d8dda1cd38ea73612b71684f539400d2167b9ec`.

## Scope

A23BL introduces a new provenance-complete transaction orchestration source set. It does not reconstruct missing P17/P18 source and does not modify SWAP physics.

The transaction controller is independent of files, calendar units and solver internals. A physical model plugs in through four operations:

- clone physical state;
- advance a trial over `[t0,t1]`;
- report physical water storage;
- compare full-step and two-half-step endpoints for temporal error.

## Reference algorithm

For every attempt:

1. clone the committed checkpoint;
2. run one full-step trial on a clone;
3. run two sequential half-step trials on another clone;
4. compute full and two-half mass residuals independently;
5. reject if either solver path fails;
6. reject if either mass residual exceeds the hard mass tolerance;
7. reject if temporal error exceeds the reference tolerance;
8. on rejection, discard all candidates and retry from the unchanged committed checkpoint with reduced `dt`;
9. on acceptance, commit only the two-half candidate.

The committed object is never used as trial workspace. Rejected trials therefore cannot mutate committed physical state by construction.

## State and ownership

The controller owns only temporary checkpoint/candidate clones and transaction diagnostics. Model physical state remains owned by the caller/model. No numerical scratch is persisted per column by this module.

## Explicit exclusions

- selective step-doubling;
- legacy file adapters;
- calendar/day control;
- B12 fixture construction;
- direct MODFLOW coupling;
- changes to physics, top Jacobian assembly, or solver policy beyond the explicit transaction retry policy.

## Qualification boundary

A23BL qualifies the transaction orchestration contract with a deterministic conservative model, including O0/O2, rollback, temporal retry, solver-failure contamination, hard mass rejection, non-calendar time and multi-worker independence.

It does **not** yet qualify SWAP hydrological output against B1.6. The next integration slice must supply a provenance-complete physical adapter and compare it against the qualified B1.6 oracle before this controller can be called a production SWAP reference route.
