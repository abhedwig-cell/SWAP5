# EB-I23 — Accepted sensible-boundary runtime materialization

## Purpose

EB-I23 binds already qualified sensible-energy authorities into one accepted runtime publication without adding new physical semantics.

Canonical base:

`integration/f-ci-canonical@3ff0f42299767d5ad5f07d031698dfcf7969ed0d`

The initial owner head `36a9b11ccf92c616805ca30094e6743765793e26` correctly failed its moving-canonical guard because F-CI71P advanced canonical during the run. EB-I23 was reconciled without production-semantic changes in two-parent commit `4c4c146faa0af6df23370d5f2267739eb910fa87`; the inherited EB authority blobs remained byte-identical.

EB-I23 is deliberately a **partial** runtime materialization. It does not make the EB-I22 whole-column boundary complete because current canonical production/reference evidence does not establish a qualified top mass-carried sensible-energy donor-temperature authority.

## Inherited authorities

The owner gate pins the following current-canonical authorities:

- restricted soil-temperature process: `src/process/mod_restricted_soil_temperature.f90` blob `fa4e1d7b48d3515e6569c9080d497178c25c4e85`;
- soil-temperature contract: `src/process/mod_soil_temperature_contract.f90` blob `baa13df3975de2c699b0ec910477bcfa9b47f15e`;
- serialized physical backend: `src/runtime/mod_fmr_serialized_reference_backend.f90` blob `3506b453ba6a00111d182f29db8cbfb288001854`;
- serialized accepted bottom-energy runtime: `src/runtime/mod_fmr_serialized_multiswap_runtime.f90` blob `1aa2454048d0e480becaee34f596f20f1a7bd66e`;
- liquid-water sensible enthalpy law: `src/process/mod_liquid_water_sensible_enthalpy.f90` blob `2247370ee34fac73a0e2d0b9fa15e171467aded3`;
- EB-I22 whole-column sensible accounting: `src/process/mod_whole_column_sensible_energy_accounting.f90` blob `c00efd8cdb4de947de16e1d32ae4c9f4d0590850`.

These sources are reused rather than redefined.

## Accepted-transaction binding

`fmr_execute_serialized_column_with_sensible_boundary_materialization` calls the already admitted receipt-owned bottom-energy transaction seam. The bottom publication and the backend thermal observation therefore remain inside one runtime call boundary.

A publication is emitted only after the underlying column result is both completed and committed and after the receipt-owned bottom publication agrees with the executing column, origin revision, committed revision and requested interval.

Rejected/pre-admission transactions produce no EB-I23 publication.

## Conductive materialization

The restricted soil-temperature authority reports whole-substep top boundary energy in `J/cm2`, positive into the soil.

For an accepted transaction with exactly one committed substep and complete restricted thermal accounting, EB-I23 publishes:

- `top_conductive_into_j_m2 = 1e4 * boundary_energy_into_soil_j_cm2`;
- `bottom_conductive_outward_j_m2 = 0` as an explicitly known boundary-condition value from the qualified restricted-temperature scope.

The bottom zero is not a missing term repaired to zero.

The adapter also checks the reported restricted-temperature accounting identity at roundoff scale before publishing the conductive values.

## Multi-substep fail-closed rule

The current serialized backend exposes only `last_observation` for soil-temperature diagnostics. With one accepted substep this is the complete accepted thermal interval. With an accepted two-half or otherwise multi-substep trajectory it is not a whole-interval conductive-energy accumulator.

Therefore EB-I23 **does not** publish top or bottom conductive energy when `accepted_substeps /= 1`.

This is intentional. A later capability may add a rollback-safe thermal-boundary carrier analogous to the existing bottom thermal carrier. EB-I23 must not sum or reconstruct rejected/trial observations after the fact.

## Bottom mass-carried sensible energy

Bottom advective sensible energy is taken only from the existing accepted, receipt-owned bottom-energy publication. Its sign convention is outward-positive `J/m2` and is transferred unchanged.

If an inward bottom transfer requires an external donor temperature and that donor temperature is unavailable, bottom advective energy remains unavailable. Missing energy is never encoded as a known zero.

The mass-carried reference temperature comes directly from the explicit qualified liquid-water sensible-enthalpy parameters.

## Top mass-carried sensible energy

Current canonical authorities expose surface water fluxes, irrigation amount/concentration and accepted evaporation attribution, but no qualified donor-temperature provenance for top liquid-water sensible transport.

EB-I23 therefore leaves:

`top_advective_available = .false.`

by construction.

It does not infer a temperature from soil state, prescribed surface temperature, air temperature, precipitation, irrigation or ponding. It does not reinterpret evaporation as liquid sensible-energy transport.

Consequently `whole_column_sensible_boundary_t%complete()` remains false and EB-I22 must continue to withhold a whole-column sensible residual.

## Qualification cases

The owner test exercises the real serialized runtime and covers:

- one accepted restricted-temperature transaction;
- exact `J/cm2 -> J/m2` conductive conversion against the same backend observation;
- explicit restricted-scope zero bottom conductive term;
- receipt-owned bottom advective energy availability;
- explicit mass-carried reference-temperature provenance;
- top advective unavailability despite nonzero top water flux;
- fail-closed bottom advective energy when the external donor temperature is unavailable;
- rejected/pre-admission transaction producing no I23 publication;
- `boundary%complete() == false` and `runtime_materialization_complete() == false`;
- GNU Fortran O0/O2 output identity.

The gate also statically locks the single-substep restriction and the absence of a top-advective availability promotion.

## Hard nonclaims

EB-I23 does not claim:

- a qualified top mass-carried sensible-energy source;
- conductive aggregation across accepted multi-substep trajectories;
- complete runtime materialization of all four EB-I22 boundary categories;
- a whole-column sensible residual in production;
- a full SWAP5 Energy Balance;
- radiation, latent heat, vapor transport, freeze/thaw, snow phase-change, pressure, chemical or salinity enthalpy;
- independent qualification;
- canonical admission.

## Next capability

Two upstream capabilities are now explicit rather than hidden:

1. a qualified top-water thermal provenance/donor-temperature contract for top mass-carried sensible energy;
2. a rollback-safe restricted-thermal boundary-energy carrier if whole-interval conductive materialization must support accepted two-half/multi-substep trajectories.

Neither gap may be repaired inside EB-I23 by inventing donor temperatures or by summing unowned trial observations.