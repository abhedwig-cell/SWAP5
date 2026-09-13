# F-CI03 qualification record

## Scope

F-CI03 forward-integrates only the qualified transaction substrate that is independent of the B1.6 physical source preimage.

Imported byte-identical source:

- `src/transaction/mod_transaction_reference.f90`
- `src/runtime/mod_a23bu_worker_execution_context.f90`

Imported byte-identical tests:

- `tests/transaction/test_transaction_reference.f90`
- `tests/runtime/test_a23bu_worker_context.f90`
- `tests/transaction/run_a23bl_gate.sh`

The A23BU physical adapter is intentionally excluded.

## Provenance

A23 source commit:

`763f276a96ee1722a465bacd3a710172a5f38107`

A23/B1.10 merge base:

`2d05eeab9d766d51bc7c436ea1e45f9b49940e92` = B1.6

Current corrected legacy oracle:

`B1.10`

B1.10 source manifest SHA-256:

`2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`

## Executed gate

GitHub Actions workflow:

`F-CI canonical qualification`

Run:

`34081057982`

Job:

`101616270891`

Qualified source/workflow head:

`31eb6a1c1a7ea04a7f1832ba6bd180d5b5d7b683`

Result:

`PASS`

The job completed the compiler check and `F-CI03 transaction and worker gate` successfully.

The focused gate covers:

- source/test Git-blob identity against A23;
- B1.10 corrected-reference presence checks;
- rejection of a wholesale A23BU physical adapter;
- strict Fortran O0 transaction build and execution;
- strict Fortran O2 transaction build and execution;
- hard mass-rejection and rollback regressions inherited from A23BL;
- non-calendar transaction interval regression;
- repeatability and parallel transaction isolation;
- strict O0/O2 worker-context build and 8 x 1000 worker-isolation regression;
- static rejection of file I/O, `SAVE` state and direct legacy production-global dependencies in the worker context.

## Qualification decision

```text
F-CI03 source provenance                  PASS
Transaction checkpoint/rollback core      PASS
Hard transaction mass rejection           PASS
Transaction generic t0/t1 boundary        PASS
Worker-owned HeadCalc scratch              PASS
Worker numerical-control isolation         PASS
Parallel worker isolation                  PASS
B1.10 physical adapter                     NOT INTEGRATED
Generic physical sub-day execution         NOT QUALIFIED
B2 reference entrypoint                    NOT YET ADMITTED
```

F-CI03 status:

`PASS_TRANSACTION_SUBSTRATE_PHYSICAL_ADAPTER_BLOCKED`

## Holds carried forward

1. The physical adapter must be rebuilt against B1.10, not regenerated from B1.6 transformers.
2. Persistent physical state must be separated from forcing, numerical configuration, reporting and legacy adapter cursors.
3. Generic physical sub-day execution through the real SWAP bridge remains a hard qualification item.
4. Scheduled irrigation, crop/WOFOST continuation and other option-specific state must be qualified before claiming a complete compact persistent state.
5. Unrounded physical mass accounting must enter the canonical result contract.
6. The full-plus-two-half transaction algorithm is retained as a reference-mode qualification path only. It is not the normal throughput policy and does not authorize selective step doubling.
