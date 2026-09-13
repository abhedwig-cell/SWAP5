# EB-I08 - External Liquid Water Temperature Contract

## Authority and purpose

Restart authority: `integration/f-ci-canonical@2a0db2524fba6e258316ce82630c60ea1c9c673a`.

EB-I08 defines a small generic contract for external liquid-water inflow thermal provenance. The contract answers only one question: if a positive external liquid-water amount is transferred into the modeled system, is an explicit finite donor-water temperature available?

It does not calculate energy and does not identify the physical source.

## Inputs

The resolver receives:

- `inflow_amount`: an already authoritative external liquid-water transfer amount;
- `external_liquid_water_temperature_t`: an availability flag and a temperature in degrees Celsius.

The resolver does not own, recalculate, normalize or store the transfer amount.

## Required behavior

1. A non-finite transfer amount is invalid.
2. A negative transfer amount is invalid because this contract represents an external inflow magnitude, not a bidirectional oriented transfer.
3. Exact zero inflow requires no donor-water temperature.
4. Every finite positive inflow requires thermal provenance, including the smallest representable positive normal `real64` value used by the qualification test.
5. There is no small-transfer tolerance or cutoff.
6. If positive inflow has no available temperature, resolution fails closed with `EXT_LIQ_TEMP_MISSING`.
7. If positive inflow has an available but non-finite temperature, resolution fails closed with `EXT_LIQ_TEMP_INVALID_TEMPERATURE`.
8. If positive inflow has an available finite temperature, the temperature is copied without modification.
9. The generic contract does not impose an arbitrary physical temperature range. Source-specific validation belongs to the source adapter or physical component.
10. An unused thermal payload is ignored when the water amount is exactly zero.

## Architectural boundary

The production module is intentionally source-agnostic. It does not know whether the external water originates from precipitation, irrigation, upstream surface water, groundwater, a transfer-zone component or another source.

The runtime or coupler remains responsible for mapping a physical external-water source to this generic contract. This preserves the separation between kernel physics and system composition.

The contract also remains mass-neutral. It receives the authoritative water amount only to determine whether thermal provenance is required. It must never become a second water-mass ledger.

## Temporal provenance

EB-I08 does not define how a water temperature varying within `[t0,t1]` is averaged or integrated. A caller must eventually provide a thermal value that is qualified for the same accepted transfer interval, or split the interval when necessary.

Therefore EB-I08 alone does not prove same-window mass-temperature consistency.

## Transaction boundary

The resolver is pure and mutates no model state. This makes it safe to call during a trial. However, EB-I08 does not itself bind a temperature to a transaction lineage, candidate state, commit receipt or rollback operation.

A later runtime composition must ensure that only thermal provenance belonging to the accepted water transfer can reach the committed energy ledger.

## Units

`temperature_c` is degrees Celsius. EB-I08 performs no unit conversion and no enthalpy calculation.

## Hard nonclaims

EB-I08 does not qualify:

- sensible heat or specific enthalpy calculation;
- a reference temperature for energy;
- internal soil-face donor selection;
- temporal quadrature or mass-weighted source temperature;
- precipitation, irrigation, runon or groundwater-specific thermal values;
- surface-water thermal storage;
- snow, ice, vapor, evaporation, sublimation or any phase-change energy;
- macropore thermal state;
- transaction publication or rollback of energy results;
- MultiSWAP throughput;
- bounded-cost behavior;
- a closed energy balance;
- independent verification;
- canonical admission.

## Owner qualification target

Owner qualification must demonstrate under GNU Fortran `-O0` and `-O2` that:

- exact zero does not require provenance;
- an unused non-finite temperature does not invalidate exact-zero transfer;
- a tiny positive transfer does require provenance;
- missing positive-transfer provenance fails closed;
- finite provided temperatures are preserved exactly;
- non-finite provided temperatures are rejected when required;
- negative and non-finite transfer amounts are rejected;
- no source-specific or previous EB production dependency is introduced.
