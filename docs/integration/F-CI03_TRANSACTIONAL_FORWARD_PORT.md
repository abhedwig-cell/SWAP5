# F-CI03 B1.10 transactional forward integration

## Decision

F-CI03 does not merge `integration/a23bk-transactional-rebase` wholesale. The A23 line diverges from the current corrected legacy oracle at B1.6. The canonical line therefore imports only qualified source whose semantics are independent of the B1.6 physical source preimage.

## Imported production substrate

The following files are materialized byte-for-byte from A23BU commit `763f276a96ee1722a465bacd3a710172a5f38107`:

- `src/transaction/mod_transaction_reference.f90`
- `src/runtime/mod_a23bu_worker_execution_context.f90`

The corresponding transaction and worker-isolation tests are also imported byte-for-byte. Git blob identity is enforced by `tools/fci/fci03_transaction_substrate_gate.py`.

This preserves already-qualified semantics instead of reconstructing them from chat history or historical patches.

## What the transaction core establishes

The imported reference transaction core provides:

- explicit committed-state checkpointing;
- isolated full and half trial states cloned from the checkpoint;
- retries from the same committed physical checkpoint;
- no mutation of committed state before acceptance;
- hard mass-residual rejection;
- explicit generic `t0,t1` at the transaction boundary;
- retry, rollback, commit and solver-cost diagnostics;
- reference-mode temporal comparison using one full plus two half trials.

The full-plus-two-half route is retained only because it is part of the qualified A23BL reference transaction source. F-CI03 does not promote it to the normal throughput policy and does not introduce selective step doubling.

## What the worker context establishes

The imported worker execution context owns:

- HeadCalc/Newton/Jacobian scratch arrays;
- solver history;
- solver diagnostics;
- numerical timestep control;
- execution-window projection state;
- reporting shim state.

This keeps expensive scratch out of persistent logical column state and provides a direct basis for homogeneous worker/batch execution.

Reporting state is worker-owned shim state here, not canonical persistent physical column state.

## Explicit rejection of the A23BU physical adapter

`src/adapter/mod_a23bu_hupsel_worker_component.f90` is deliberately not imported.

Reasons:

1. it was qualified against a B1.6 physical source lineage, while B1.10 contains later corrected-reference changes;
2. `hupsel_column_state_t` still combines physical state with forcing cursors, numerical state, legacy time projection, replay cache and accounting cursor;
3. the current real Hupsel bridge requires whole/integer-day intervals and rounds `t0,t1` into a legacy day projection;
4. it still calls the legacy file-oriented SWAP initialization seam, acceptable only as an external adapter but not as the canonical kernel contract;
5. scheduled/sub-day irrigation and additional process-continuation cases remain explicitly unqualified in A23BU evidence.

Therefore copying that adapter would violate the F-CI consolidation rules even if it compiled.

## B1.10 preservation

The canonical corrected-reference oracle remains B1.10 with source manifest:

`2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`

F-CI03 explicitly requires the B1.10 chain to contain SWAP-010, SWAP-013, SWAP-012 and SWAP-002. No B1.6 source transformer is permitted to regenerate physical source on the canonical line.

## Focused qualification

Run:

```bash
bash tests/fci/run_fci03_gate.sh
```

The gate performs:

- exact Git-blob provenance checks for imported source/tests;
- a fail-closed check that the wholesale A23BU physical adapter is absent;
- B1.10 corrected-reference pin checks;
- A23BL transaction O0/O2 build and regression execution;
- worker-context O0/O2 build and 8 x 1000 parallel isolation checks;
- static rejection of file I/O, module `SAVE` state and legacy production-global dependencies in the worker context.

## F-CI03 holds

F-CI03 is not yet the integrated B2 reference implementation. The following remain blockers for the next integration unit:

- implement a B1.10-based physical adapter from the canonical data categories rather than from the A23BU monolithic state type;
- prove generic physical sub-day intervals through the real physical bridge;
- qualify exact physical continuation state, especially irrigation/crop continuation;
- bind unrounded physical mass accounting to the canonical result contract;
- keep the expensive full-plus-two-half transaction route reference-only unless later qualification explicitly changes policy.

## Architecture invariant assessment

F-CI03 directly advances invariants 1, 3, 4, 5, 6, 7, 8, 9, 13, 16, 23, 25, 26, 29 and 30. It intentionally does not claim completion of the coupling, generic physical-time or final state-layout invariants.
