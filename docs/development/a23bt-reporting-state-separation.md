# A23BT Reporting State Ownership Contract

## Status

`PASS_REPORTING_STATE_SEPARATION_AND_TRIAL_OUTPUT_SUPPRESSION / PRODUCTION_REPORTING_DELIVERY_PENDING / PHYSICAL_BACKEND_SERIAL_ONLY`

## Decision

Reporting and output progression is **not physical or numerical continuation state**. It must not be cloned into every transaction checkpoint or committed column state. On the qualified Hupsel/B1.6 bridge A23BT therefore keeps reporting progression in a small worker-side legacy shim used only to satisfy legacy scheduling/reset semantics while a trial is executing.

The canonical transaction path remains generic `[t0,t1]`. It never emits legacy output from full, shadow, rejected, or replay trials. A future runtime/reporting layer may consume committed results and maintain reporting cursors independently.

## Worker-side legacy reporting shim

The shim contains `nprintcount`, `cntper`, `ioutdat`, `ioutdatint`, `outper`, `tcumold`, output/header flags, and the reporting-driven accumulator reset controls `reset_intermediate` and `reset_cumulative`. GNU Fortran payload accounting is **56 B per worker**. No A23BT reporting field is stored in `hupsel_column_state_t`.

`tcumold` is no longer a module `SAVE` on the worker route. The dynamic `TimeControl` branch uses the worker shim. `integral` and `solute` receive reset controls explicitly and do not read global `flzerointr`/`flzerocumu`. Those legacy globals remain only for initialization/non-worker compatibility source and are not authoritative for the qualified transaction path.

## Trial output rule

With a worker present, the legacy output-dispatch block in `swap.f90` is bypassed. This includes `SwapOutput(2)`, `SoilWaterOutput(2)`, tillage output, `Solute(3)`, and macropore output. The focused test verifies that `.BAL` and `.BLC` sizes do not change during the always-sampled transaction.

This is an **output-side-effect** qualification. It is not a claim that the legacy adapter is fully file-I/O-free; forcing/configuration I/O may still exist outside the new kernel contract.

## Qualified schedule

This cut is qualified only for the existing Hupsel reference schedule:

- `NPRINTDAY = 1`;
- `FLPRINTDT = .false.`;
- the current legacy bridge still accepts whole-day boundaries.

Subdaily reporting schedules remain a production hold. They must not be enabled by silently reintroducing reporting boundaries as kernel timestep boundaries.

## Transactional invariants

1. Full and two-half trials begin from the same committed column state.
2. Reporting shim state is reseeded per trial and is never committed as physical state.
3. Poisoned global reporting counters/flags cannot affect the next logical column.
4. Poisoned global `flzerointr`/`flzerocumu` cannot affect worker-route `integral` or `solute`.
5. Rejected/shadow trials cannot emit accepted legacy output.
6. Mass conservation remains a hard gate.
7. No physics, Jacobian formula, solver policy, or selective-step-doubling policy changes are admitted in A23BT.

## Evidence

- B1.6 parent manifest: `aad530d2b683aa25ed8d5ec87656fb3790b8d8f8faf6bff4b03d40a4c60136a0`
- physical endpoint: `4b77a52ca7c48a59a057dec036f596a8da4ebc9ede9296f7d3b36dcff528bfb9`
- O0/O2 physical log SHA-256: `5520a76c3ccffe3b3a03af3867a6544b0147ddedd817385b76b91359f1043e63`
- accepted storage: `77.011710672204643 cm`
- mass residual: `-1.7872350177583485e-7 cm`
- Jacobian_F SHA-256: `83a0405484bb11b97a4ad6d8eed908f6a6b478a748c2b9056eba44299b0e427a` and byte-identical to A23BS
- worker isolation: 8 workers, 8,000 checks, 0 failures

## Architecture invariants

Directly supports invariants 2, 3, 4, 5, 7, 9, 13, 26, 27, 28 and 29. In particular, output scheduling remains outside the physical state model and calendar/reporting boundaries are not elevated into fundamental kernel time units.
