# A23BO component ownership contract

## Scope

A23BO converts the A23BN Hupsel replay capsule into explicit ownership categories while retaining B1.6 as a serialized verification backend.

## Column-owned categories

`hupsel_column_state_t` is a composite transaction state with separate categories:

- `physical`: pressure head, water content, soil temperature, solute concentration and physical continuation scalars;
- `forcing`: meteorological progression cursor only;
- `process`: irrigation/crop progression state required for exact continuation;
- `numerical`: current legacy timestep continuation (`dt`), explicitly not physical state;
- `replay`: `cmsy(:)`, a legacy derived cache required for exact same-process replay;
- `accounting`: legacy cumulative water-balance cursors required only to make per-column VQ diagnostics order independent.

The last two categories are transitional adapter state. They are not automatically part of the final SWAP5 persistent physical state. `accounting` in particular must disappear when the native physics API returns interval flux results directly instead of relying on cumulative global counters.

## Execution ownership

A23BL remains transaction owner. A23BO restores one complete logical column context into the current B1.6 singleton, performs one physical advance, captures the column context again and returns interval-local diagnostics.

Multiple logical column states can therefore be serially multiplexed through the same legacy backend without state or diagnostic contamination. This does not make the B1.6 backend thread-safe; parallel workers remain future work.

## Solver diagnostics

`trial_outcome_t` now carries `internal_retries` in addition to nonlinear iterations. `transaction_result_t` distinguishes:

- total nonlinear iterations and internal retries spent across full and two-half reference trials;
- nonlinear iterations and internal retries on the accepted two-half route.

A measurement-only hook is placed at the existing B1.6 `fldecdt` reduction branch. The hook changes no timestep policy and no physics. For the Hupsel 4-5 January interval it reports 0 retries on 4 January and 10 on 5 January. The always-sampled reference transaction therefore spends 20 internal retries in total and commits a route that spent 10.

## Mass accounting

Mass conservation remains a hard A23BL acceptance condition. The legacy accounting cursor is restored with each logical column so interval mass diagnostics are exactly independent of execution order. It is classified separately from physical state to prevent legacy reporting mechanics from becoming a target-kernel state contract.

## Production boundary

The A23BO API is per-column and state-explicit, but the wrapped B1.6 physics is still module-global and may only be invoked serially. No claim of MultiSWAP thread safety or worker-owned Newton/Jacobian scratch is made.
