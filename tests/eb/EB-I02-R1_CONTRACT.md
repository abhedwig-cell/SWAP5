# EB-I02-R1 — Soil Thermal Conservation Contract

## Authority and purpose

EB-I02-R1 is an additive conservation-view capability on top of the already admitted restricted soil-temperature science. It does not replace or modify F-PM07B/F-VQ58/F-CI43/F-MR39/F-CI45 thermal physics or transaction semantics.

Restart authority for the qualified R1 composition is:

`integration/f-ci-canonical@2a0db2524fba6e258316ce82630c60ea1c9c673a`

The production delta is exactly:

`src/process/mod_soil_thermal_energy_contract.f90`

The previously admitted thermal seams remain byte-identical:

- `mod_soil_temperature_contract.f90` blob `baa13df3975de2c699b0ec910477bcfa9b47f15e`
- `mod_restricted_soil_temperature.f90` blob `fa4e1d7b48d3515e6569c9080d497178c25c4e85`
- `mod_process_hydraulic_view.f90` blob `d7d85fe71ced0d94b29c8d9395859ae1834f7dd6`

## Units and signs

The new view reports interval-integrated energy in `J/m2` of the owning logical SWAP column/tile area.

Positive top conductive energy is energy entering the soil. The existing F-PM07B zero-bottom-flux restriction maps to exactly zero bottom conductive energy. Existing `J/cm2` result quantities are converted by the exact area factor `1e4`.

## Coverage semantics

A successful view can assert only:

- sensible thermal storage accounted;
- top conductive energy accounted;
- bottom conductive energy accounted within the admitted zero-bottom-flux restriction;
- restricted sensible-conduction residual available.

It explicitly does **not** assert:

- liquid-water advective enthalpy accounted;
- vapor transport energy accounted;
- freeze/thaw or other phase-change enthalpy accounted;
- prognostic surface-energy balance accounted.

Therefore `full_physical_energy_complete()` is false for every EB-I02-R1 view by construction.

The historical `soil_temperature_diagnostics_t%energy_accounting_complete` remains untouched because F-VQ58 explicitly qualified that flag inside the frozen restricted sensible-heat scope. EB-I02-R1 exposes it only as `legacy_restricted_energy_accounting_complete`; it is not promoted to a general physical-energy-closure claim.

## Hydraulic dependency boundary

`process_hydraulic_view_t` currently carries pressure head, water content, ponding depth and groundwater level, but no phase-resolved water-interface fluxes. Consequently neither changing nor unchanged water content is sufficient evidence that water-carried energy is zero.

A later capability must supply qualified `q_liquid` and, where applicable, `q_vapour` interface fluxes before advective/vapor energy coverage can become true.

## Fail-closed rules

The view is unavailable when:

- `[t0,t1]` is invalid or non-finite;
- the restricted thermal result was not successfully produced;
- required result values are non-finite;
- the admitted prescribed-surface-temperature or zero-bottom-flux boundary markers are absent;
- snow or frost is marked active;
- `boundary_energy != dt * top_heat_flux` beyond roundoff tolerance;
- `energy_residual != sensible_storage_change - boundary_energy` beyond roundoff tolerance.

## State and transaction semantics

EB-I02-R1 adds no physical state, no restart state and no worker scratch. It is a derived view of a successfully produced restricted thermal trial result. Existing F-MR39/F-CI45 atomic water+thermal commit/rollback authority remains unchanged.

## Relationship to EB-I01

EB-I02-R1 deliberately has no source dependency on the unadmitted EB-I01 energy ledger. After both capabilities have been independently qualified/admitted, a separate composition workunit may map the EB-I02 interval view into EB-I01 trial-local transfer/accounting records.

## Nonclaims

EB-I02-R1 is not a closed SWAP5 land-surface energy balance, does not add heat advection, does not add vapor latent transport, does not add snow/freeze enthalpy, does not solve `Rn-H-LE-G`, and does not validate empirical surface-energy science.
