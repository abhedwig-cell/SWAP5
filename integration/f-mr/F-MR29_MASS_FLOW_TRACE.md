# F-MR29 — Actual-Transpiration Accounting & Mass-Attribution Readiness

## Current authority

Source authority is `integration/f-ci-canonical@e3964ec0ef312f974461aeac70fb9bc5720803e3`.

This workunit starts from the exact current canonical state and does not inherit source authority from F-MR28 or F-VQ46 qualification branches.

## Observed canonical flow

1. `mod_fmr_reference_et_root_uptake_composition` binds reference-ET potential transpiration to the restricted root-uptake request and returns `root_water_uptake_flux_result_t`.
2. `root_water_uptake_flux_result_t` contains both the nodewise `root_extraction_sink(:)` and `actual_uptake_total = sum(root_extraction_sink)`.
3. The restricted serialized Richards forcing already carries `root_extraction_sink(:)` as `fmr_b110_physical_forcing_t%root_extraction_sink`.
4. When root extraction is active, the serialized backend binds that exact array to the dedicated B1.10 root-sink provider as `qrot`.
5. The same backend calls `account_external_fluxes` after a converged physical trial.
6. `account_external_fluxes` integrates every `qrot(i)` over the exact solver `step_duration` and adds non-negative root extraction to transaction `mass_out`.
7. `mod_transaction_reference` evaluates the hard water-balance residual as `storage_end - storage_start - (mass_in - mass_out)` and commits only an accepted transactional route.

## Immediate scientific conclusion

The current canonical Richards transaction already counts root extraction exactly once as external water mass outflow through `qrot * dt`.

Therefore a future actual-transpiration result must **not** independently add `actual_uptake_total * dt` to transaction `mass_out`. Doing so would double count the same physical sink and can violate hard mass conservation.

The correct architectural problem is attribution/publication, not a missing physical water sink.

## Contract hypothesis to qualify

The smallest safe contract is:

- `root_extraction_sink(:)` remains the sole physical sink supplied to the soil-water solver;
- transaction `mass_out` remains the sole authoritative water-balance booking of that physical sink;
- `actual_uptake_total` is exposed as a derived instantaneous process/result quantity, not a second mass contribution;
- any accepted-interval transpiration amount is derived only from the exact root-sink trajectory actually used by the accepted transaction route;
- rejected full/half trials, retry attempts and rolled-back states may never leak transpiration totals into committed/public results;
- published accepted transpiration must reconcile exactly with the root-extraction contribution already present in accepted transaction `mass_out`, without changing that mass ledger;
- attribution must remain distinguishable from other external outflows such as top evaporation, bottom drainage and drainage-system sinks.

## Key unresolved question

`actual_uptake_total` produced before the soil-water transaction is only the precomputed process rate for the current committed hydraulic view. The transaction layer may execute a full trial, two half trials, retries, or later other solver policies. F-MR29 must prove whether this precomputed rate is identical to the root sink used for every accepted subtrial in the frozen scope, and define how accepted transpiration is reconstructed when a transaction accepts a shortened/retried interval.

## Hard gates

1. No duplicate mass booking.
2. Accepted transpiration attribution equals the already-booked accepted root-sink mass contribution within exact/qualified arithmetic semantics.
3. Rejected trials do not publish or accumulate transpiration.
4. Retry/rollback preserves committed state and committed attribution.
5. Time integration uses actual accepted solver intervals, never an assumed day/calendar interval.
6. The contract remains valid for serialized execution first; parallel root extraction stays explicitly outside this workunit.

## Invariant assessment

This workunit directly protects invariants 3, 7, 8, 9, 13, 16, 23, 26 and 29. It does not alter physics, numerical policy, solver ownership, persistent state or I/O boundaries.
