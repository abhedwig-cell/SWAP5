# F-CI09 Qualification

Status: **PASS — transaction binding substrate; physical reference execution remains blocked.**

## Qualified source

- canonical branch: `integration/f-ci-canonical`
- qualified F-CI09 source head: `3e10ef4c0d04d937d01b4619a72117b6aaea6889`
- canonical workflow run: `34091724307`
- F-CI09 job: `101646644706`
- compiler: GNU Fortran 13.3.0

The complete sequential F-CI03 through F-CI09 workflow passed on this persisted postimage.

## Passed scope

F-CI09 qualifies the canonical B1.10 transaction **binding substrate**:

- `b1_10_transaction_model_t` is a real `transaction_model_t` subtype;
- committed physical state is captured/restored as `b1_10_process_state_t`;
- non-persistent legacy trial state is captured/restored as `b1_10_attempt_context_t` containing the worker-local legacy capsule;
- physical state cloning preserves the dynamic state type;
- O0 and O2 binding tests pass with identical normal output;
- a blocked `advance` cannot silently execute the legacy backend;
- an unqualified `storage` invocation fails closed with the expected `mass storage contract not admitted` diagnostic;
- the binding contains no direct file I/O and no direct call to legacy `SWAP`.

The source-bound whole-day physical restore/rerun evidence from F-CI08 remains valid and is inherited as supporting evidence, but it does not upgrade the B1.10 backend to generic interval execution.

## Explicit non-admission

The following capabilities remain deliberately unavailable:

- generic physical `[t0,t1]` / sub-day advance;
- unrounded per-trial mass-in and mass-out extraction;
- complete physical storage accounting for the transaction mass gate;
- a qualified physical temporal-error metric;
- use of B1.10 through `execute_reference_interval`.

This boundary is essential. The reference transaction core requires a full trial plus two half trials from one checkpoint, whereas the current B1.10 legacy time controller still projects execution onto calendar days and the external exchange route explicitly enforces one-day semantics. A half trial may therefore not be represented as a whole legacy day.

## Gate

The qualified gate is:

```bash
bash tests/fci/run_fci09_gate.sh
```

Canonical result: `FCI09_GATE_PASS`.

Static source pins, type/ownership checks, O0/O2 execution and the fail-closed negative storage control all passed in workflow run `34091724307`, job `101646644706`.

## Architecture result

F-CI09 strengthens the transaction architecture without altering physical formulas, Jacobians, solver policy, mass tolerances or reference step-doubling semantics. It preserves the distinction between persistent column physics and worker-local rollback bookkeeping, and it refuses to hide legacy calendar assumptions behind the generic canonical API.

## Remaining integration dependency

Before physical B1.10 reference transactions can be admitted, the production integration line must qualify a generic physical interval seam together with unrounded mass accounting and a temporal comparison contract. That is the appropriate next integration unit; simply enabling `execute_reference_interval` is not.
