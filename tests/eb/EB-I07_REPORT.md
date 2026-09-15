# EB-I07 - Water-Transfer Temperature Provenance Readiness

## Authority and scope

Restart authority: `integration/f-ci-canonical@2a0db2524fba6e258316ce82630c60ea1c9c673a`.

This workunit is a source audit only. It adds no production physics, no new runtime binding and no energy ledger behavior. Owner branches EB-I03 through EB-I06 are deliberately not used as canonical evidence.

## Main finding

Current canonical is substantially further developed for water-mass provenance than for water-temperature provenance.

The code already contains explicit mass routes for irrigation, drainage, root uptake, snow, surface water, top/bottom soil-water exchange and groundwater coupling. It also contains a separate transactional soil-temperature state and a node-temperature field view. However, no audited current-canonical contract binds an accepted water transfer to an authoritative donor-water temperature or enthalpy.

Therefore a future advective-energy ledger must not reconstruct donor temperature from naming conventions, air temperature, neighboring soil temperature or groundwater head. Missing thermal provenance must remain explicit.

## Important source observations

### Soil water and soil temperature are correctly separated

`soil_water_solve_result_t` exposes top and bottom fluxes, but not a public accepted internal face-flux vector. `process_hydraulic_view_t` contains pressure head, water content, ponding depth and groundwater level, but no temperature.

Separately, `soil_temperature_state_t` owns the temperature profile and `soil_temperature_field_view_t` exposes node temperatures. This is a sound architectural separation, but the transport binding is missing.

### Top-boundary source identity exists below the canonical runtime surface

`b110_dynamic_top_boundary_request_t` distinguishes precipitation, irrigation, snowmelt and runon. This is exactly the source identity an energy implementation needs before those terms are combined into a net surface-water forcing.

The serialized canonical forcing contract does not itself expose those four thermal source identities. It carries a generic top flux plus separate drainage, subsurface irrigation, root extraction, snow and soil-temperature objects. End-to-end thermal provenance is therefore not proven by current canonical.

### External inflows have no thermal authority

Surface irrigation exposes gross rate and external inflow amount. Subsurface irrigation exposes node sources. Groundwater coupling exposes flux and head. Fixed-weir surface water exposes supply rate. None of these audited contracts carries donor-water temperature or enthalpy.

No future energy implementation may silently use air temperature for rain or irrigation, bottom-soil temperature for incoming groundwater, or a zero-energy default when the thermal property is missing.

### Local soil outflows are closer, but still not qualified

Drainage and root uptake are node resolved. Bottom outward exchange is explicit. Local soil temperature is available when the optional soil-temperature state is active.

This makes a same-window donor-temperature binding feasible, but it is not yet a current-canonical capability. Root uptake also requires an explicit control-volume assumption before local soil-water temperature can be treated as the energy carried across the soil-root boundary.

### Bottom exchange is directionally asymmetric

For SWAP-to-groundwater outflow, the donor is local bottom soil water, so bottom-soil temperature can in principle become the donor authority after transactional binding and qualification.

For groundwater-to-SWAP inflow, the donor is external groundwater. Current groundwater coupling provides head and flux but no groundwater thermal property. Upward inflow therefore requires an explicit groundwater-temperature or groundwater-enthalpy contract. It must not inherit SWAP bottom-soil temperature by assumption.

### Surface water needs its own thermal state

Runoff and fixed-weir discharge have water-mass authorities but no pond/surface-water temperature state. A closed land-column energy balance therefore needs a surface-water thermal state or an equivalent explicit outflow enthalpy authority before these routes can be qualified.

### Snow and evaporation remain phase-aware work

Snowmelt, rain-on-snow, sublimation and evaporation cannot be qualified by a liquid sensible-advection primitive alone. The current snow model has water-equivalent storages and uses air temperature in a melt heuristic, but that does not constitute a snow enthalpy state or an authoritative rain-water temperature.

These routes require phase-aware enthalpy and latent-energy accounting.

## Readiness disposition

The machine-readable matrix in `tests/eb/EB-I07_PROVENANCE_MATRIX.json` records 18 routes. The resulting categories are:

- `BLOCKED_MASS_AUTHORITY`: accepted transfer mass is not public at required resolution;
- `BLOCKED_EXTERNAL_TEMPERATURE`: mass exists but the external donor thermal property is absent;
- `LOCAL_TEMPERATURE_BINDING_MISSING`: local soil temperature exists separately but is not bound to the accepted transfer;
- `SURFACE_THERMAL_STATE_MISSING` or `THERMAL_STATE_MISSING`: donor storage has no thermal state;
- `PHASE_ENERGY_CONTRACT_REQUIRED`: latent/phase physics is required;
- `CAPABILITY_NOT_RUNTIME_PROVENANCE`: process-level source identity exists but end-to-end runtime provenance is not proven.

## Architecture consequences

1. Preserve mass-source identity until donor enthalpy has been assigned. Do not collapse precipitation, irrigation, snowmelt and runon into one thermal flux before provenance is known.
2. Add explicit external-water thermal provenance for precipitation, irrigation, runon and groundwater inflow.
3. Bind local soil outflows to the accepted same-window soil-temperature state rather than to committed state from the wrong trial.
4. Treat energy publication transactionally: rejected hydraulic/thermal trials must never enter the committed energy ledger.
5. Do not add temperature to `process_hydraulic_view_t` merely for convenience. A dedicated thermal view/binding preserves the explicit data separation already present.
6. Keep phase-change routes outside a liquid sensible-advection shortcut.
7. Keep optional thermal state optional so columns without thermal physics do not pay the memory cost.

## Recommended next seams

The audit supports three distinct next design seams rather than one large energy patch:

- an external-water thermal provenance contract for precipitation, irrigation, runon and groundwater inflow;
- a transactional local donor-temperature binding for accepted soil outflows, drainage and root extraction;
- separate surface-water and snow/phase enthalpy work before runoff, weir discharge, melt, sublimation and evaporation are declared energy closed.

The order matters. Thermal provenance should be explicit before a production advective-energy ledger begins summing Joules.

## Nonclaims

EB-I07 does not qualify a closed energy balance, advective heat transport, a specific upwind discretization, external-water temperatures, surface-water temperature, snow enthalpy, evaporation latent heat, macropore thermal equilibrium, MultiSWAP performance, independent verification or canonical admission.
