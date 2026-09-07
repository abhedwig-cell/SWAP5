# F-CI13 — Recoverable Physical Trial Status Contract

## Purpose

F-CI13 distinguishes recoverable numerical trial failure from fatal configuration/contract failure without changing SWAP physics, convergence tolerances, timestep policy or mass tolerances.

## Legacy failure classification

The exact current HeadCalc source shows three materially different numerical paths:

1. A failed tridiagonal solve invokes the existing alternative solver. This is not an outer transaction failure if that route completes.
2. Nonconvergence above `dtmin` restores the current soil-water step, sets `fldecdt`, and lets `TimeControl(5)` reduce the internal timestep. This remains an internal SWAP retry.
3. Persistent nonconvergence at minimum timestep reaches the historical terminal branch. Legacy increments `worker%history%iwarn`, warns, and continues with a nonconverged solution.

For a canonical transactional trial only, case 3 is now intercepted immediately after `SoilWater(2)`. The step water state is restored and control returns before surface-water postprocessing, `SoilWater(3)`, mass integration, process-state updates or time advancement. Standalone execution has no worker argument and retains the qualified B1.10 legacy behaviour.

`swap_error` paths remain fatal contract/configuration failures. They are deliberately not reclassified as retryable numerical failures.

## Status contract

`mod_b1_10_trial_status` defines explicit `SUCCESS`, `RETRYABLE_NUMERICAL` and `FATAL_CONTRACT` classes plus stable reason codes. The F-CI13 executor resets only attempt-local warning observation, executes the existing generic interval seam, invalidates trial mass on failure, and maps the minimum-dt terminal marker to `RETRYABLE_NUMERICAL`.

`b1_10_recoverable_reference_model_t` extends the F-CI12 model. Retryable numerical failure returns `solver_ok=.false.` after restoring the physical trial start. Fatal contract results fail closed and are never passed into the transaction retry loop.

## Source materialization

F-CI13 does not alter the F-CI11 postimage. `src/legacy/b1_10_fci13_port` is a complete successor SWAP postimage assembled from the exact unchanged F-CI11 chunk blobs except for `swap_part05.inc`, whose only admitted difference is the guarded canonical terminal-nonconvergence return.

## Admission boundary

F-CI13 can qualify recoverable Richards terminal failure propagation, but does not admit `execute_reference_interval`. The scalar temporal-error policy is still deliberately absent. Optional-process temporal coverage, snow/macropore storage/failure handling and reentrant legacy execution remain open.

## Architecture check

This advances invariants 3, 5, 7, 8, 13, 23, 24, 25, 26 and 29. It does not change a physical formula or solver policy and it prevents a known nonconverged physical trial from being silently treated as accepted transactional state.
