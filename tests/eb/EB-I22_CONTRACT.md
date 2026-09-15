# EB-I22 — Whole-column sensible-energy accounting

## Purpose

EB-I22 establishes one bounded conservation-accounting capability for the SWAP5 soil column. It combines the exact current linear-mixture sensible-storage state law with explicitly oriented top and bottom sensible-energy boundary terms and projects the result through the already admitted generic energy-conservation balance algebra.

This capability is deliberately narrower than a full SWAP5 Energy Balance.

Canonical base:

`integration/f-ci-canonical@366a4d9b4afddb9e1f878a6d371fdff836babaac`

## Inherited authorities

EB-I22 reuses rather than redefines the following authorities:

- `src/process/mod_soil_temperature_contract.f90` blob `baa13df3975de2c699b0ec910477bcfa9b47f15e`;
- `src/process/mod_restricted_soil_temperature.f90` blob `fa4e1d7b48d3515e6569c9080d497178c25c4e85`;
- `src/kernel/mod_energy_conservation_types.f90` blob `15a6a9c5c5da6ad0d535c27772e57a23e618658d`;
- the previously owner-qualified EB-I05 exact sensible-storage state law, replayed byte-identically as `src/process/mod_linear_mixture_sensible_storage.f90` blob `0403c23454a879356ce8d2345006df130484067d`.

The current restricted soil-temperature sources are byte-identical to the thermal sources against which EB-I05 was qualified. EB-I22 therefore treats the I05 replay as inherited scientific evidence, subject to the new current-canonical race guard and I22 qualification.

## Whole-column sensible storage

For every soil compartment `i`, EB-I22 uses the EB-I05 state function

`U_i = 1e4 * dz_i * C_i(theta_i) * (T_i - T_ref)` [J/m2].

The column storage is the sum over compartments. The interval storage change is evaluated from the exact endpoint states, not only from `C(theta_avg) * DeltaT`.

The result separately exposes:

- exact endpoint storage change;
- the temperature-change component;
- the water-for-air composition-change component;
- the algebraic decomposition residual.

This avoids silently losing the composition-storage term when water content changes.

## Boundary orientation

The bounded sensible-energy control volume requires four explicit boundary categories:

1. top conductive energy, positive into the soil column;
2. top mass-carried sensible energy, positive into the soil column;
3. bottom conductive energy, positive outward from the soil column;
4. bottom mass-carried sensible energy, positive outward from the soil column.

Negative values represent flow in the opposite direction. EB-I22 converts these signed physical orientations into explicit external-to-column or column-to-external transfers and delegates the final conservation projection to `mod_energy_conservation_types`.

A zero value is a valid known zero. An unavailable term is not a zero.

## Fail-closed completeness

EB-I22 does not publish a projected residual unless all four boundary categories are explicitly available. If any category is unavailable, storage evidence remains available but `sensible_scope_complete` stays false and the projected balance stays unavailable.

This rule is required because the current production system does not yet expose every required top-boundary sensible-energy term through one accepted transactional composition.

## Reference-temperature coherence

Sensible storage under changing water content depends on the chosen reference temperature. Mass-carried sensible energy does as well. A residual is therefore meaningful only if storage and mass-carried boundary energy use the same reference convention.

EB-I22 requires an explicit mass-carried reference temperature and rejects a mismatch with `WCSA_REFERENCE_MISMATCH`. `T_ref` must not be tuned to reduce a residual.

## Relation to current production capabilities

The current restricted soil-temperature process already provides a top conductive boundary-energy result and explicitly uses zero bottom conductive heat flux in its restricted scope. Those values are expressed in `J/cm2` and require an explicit unit-safe runtime adapter before use in this `J/m2` accounting contract.

The admitted EB bottom-energy line provides mass-carried bottom sensible energy in `J/m2`, including external-donor provenance handling.

EB-I22 does not yet bind those runtime producers into one accepted receipt. In particular, top mass-carried sensible energy for surface water exchange is not yet a canonical production binding. Therefore the present SWAP5 runtime must remain fail-closed rather than claiming a complete whole-column sensible residual.

## Qualification cases

The I22 owner test covers:

- a two-compartment exact storage sum;
- explicit recovery of the composition-storage term;
- mixed-direction top and bottom boundary orientation;
- an exactly closed synthetic whole-column sensible residual;
- fail-closed behavior for an unavailable top advective term;
- rejection of a mismatched mass-carried reference gauge;
- rejection of water content outside the qualified `0 <= theta <= theta_sat` storage domain;
- GNU Fortran O0/O2 evidence identity.

## Hard nonclaims

EB-I22 does not claim:

- a complete SWAP5 Energy Balance;
- net radiation or a surface radiation budget;
- latent heat of evaporation or condensation;
- vapor sensible/latent transport;
- freeze/thaw enthalpy or snow phase-change closure;
- temperature-dependent thermophysical properties;
- pressure, chemical or salinity enthalpy;
- runtime materialization of all four boundary categories;
- accepted-transaction publication of a whole-column residual;
- independent verification;
- canonical admission.

The next production-facing capability should bind the admitted soil-temperature top conductive result, the zero/nonzero bottom conductive contract, accepted bottom advective energy, and a newly qualified top mass-carried sensible-energy source into this accounting contract without weakening its fail-closed completeness or reference-gauge rules.
