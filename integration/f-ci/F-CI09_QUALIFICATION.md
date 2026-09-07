# F-CI09 Qualification

Status at materialization: **GATE PENDING**.

## Scope

This qualification covers only the canonical B1.10 transaction binding substrate:

- committed `b1_10_process_state_t` capture/restore through a `transaction_model_t` subclass;
- worker-local legacy trial capsule capture/restore through a `transaction_attempt_context_t` subclass;
- fail-closed capability gating for generic interval advance, mass storage, trial mass fluxes and temporal error;
- provenance pins to the already-qualified F-CI06/F-CI08 source postimages.

It does not qualify physical sub-day execution and does not admit B1.10 to `execute_reference_interval`.

## Required gate

```bash
bash tests/fci/run_fci09_gate.sh
```

Expected after execution:

- static provenance/capability audit PASS;
- O0 binding test PASS;
- O2 binding test PASS;
- O0/O2 output identical;
- negative mass-storage control fails with the expected fail-closed diagnostic.

Canonical GitHub Actions execution evidence will be recorded after the persisted postimage is tested.
