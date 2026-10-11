# F-CI09 — Canonical B1.10 Transaction Model Binding

## Purpose

F-CI09 binds the qualified B1.10 physical continuation state and worker-local legacy rollback context to the canonical `transaction_model_t` type hierarchy without pretending that the current legacy time controller can execute generic physical sub-intervals.

This work unit is deliberately fail-closed. It materializes the type and ownership binding now, while leaving physical reference execution blocked until the missing interval, mass and temporal-error contracts are qualified.

## Admitted binding substrate

`src/adapter/mod_b1_10_transaction_binding.f90` introduces:

- `b1_10_transaction_model_t`, extending `transaction_model_t`;
- `b1_10_attempt_context_t`, extending `transaction_attempt_context_t` and containing the existing worker-local `b1_10_legacy_trial_capsule_t`;
- capture/restore of `b1_10_process_state_t` as committed physical state;
- capture/restore of the legacy trial capsule as non-persistent attempt context;
- an explicit capability record separating what is qualified from what is not.

The binding does **not** put forcing cursors, reporting progress, balance accumulators, solver scratch or mutable legacy time control into persistent column state.

## Why physical reference execution remains blocked

The canonical reference transaction routine requires, per attempt, a full trial and two half trials over the requested interval. The current B1.10 controller cannot yet represent those intervals generically:

- `TimeControl` terminates runs using rounded calendar-day values (`nint(tend)` / `nint(t1900)`);
- `t1900` is rounded back to an integer day at day boundaries;
- the event limiter uses `1.0 - tcum` as an end-of-day boundary;
- the external exchange route explicitly accepts only a single day (`TEND == TSTART`).

Therefore a half trial must not be emulated as a whole calendar day, and the reference transaction policy must not be weakened merely to fit the legacy adapter.

## Capability lock

The following are admitted:

- process-state type binding;
- attempt-context type binding;
- F-CI08 whole-day restore/rerun evidence.

The following remain false and cause fail-closed behavior:

- generic interval advance;
- unrounded trial mass-in/mass-out contract;
- physical storage contract used by the transaction mass gate;
- physical temporal-error metric;
- `execute_reference_interval` admission for the B1.10 backend.

`advance` therefore returns a rejected trial without executing legacy physics. `storage` and `temporal_error` stop explicitly if called before their contracts are admitted. This prevents accidental use of guessed storage formulas or mixed-unit error metrics.

## Qualification gate

`tests/fci/run_fci09_gate.sh` pins the exact F-CI08/F-CI06 source postimages, compiles the binding and tests at `-O0` and `-O2`, verifies state/context round trips, exercises a blocked advance, and contains a negative control proving that unqualified mass storage fails closed.

The gate also checks that the binding contains no direct file I/O and no direct `SWAP` call.

## Architecture invariant check

F-CI09 advances invariants 2, 3, 4, 5, 7, 8, 9, 13, 23, 25, 26 and 29. In particular:

- persistent physical state and trial-only bookkeeping remain separate;
- no new file/path knowledge enters the transaction binding;
- rejected/unqualified execution cannot silently mutate physical state;
- no calendar assumption is hidden behind a generic `[t0,t1]` API;
- mass conservation is not approximated with an unqualified storage formula;
- reference-mode semantics are preserved rather than weakened.

## Next dependency

The next physical integration step must qualify a generic physical interval seam before this model can be admitted to `execute_reference_interval`. That work also needs an explicit unrounded mass interface and a defined temporal-error metric. These requirements belong to the production integration line; they are not test-only conveniences.
