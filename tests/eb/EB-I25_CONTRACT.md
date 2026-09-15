# EB-I25 — Accepted multi-substep sensible-boundary runtime materialization

## Qualified question

Can the already admitted EB-I22/I23/I24 sensible-boundary contracts be materialized for an accepted multi-substep transaction without leaking rejected trial work, inventing donor temperatures, or changing the thermodynamic laws?

## Bounded production change

EB-I25 adds one worker-local top sensible-boundary carrier to the serialized reference backend. The carrier is transaction attempt-context scratch. It records, per physical substep, only:

- the substep interval;
- canonical signed top liquid exchange (`+` leaves soil, `-` enters soil);
- the already qualified restricted-soil-temperature boundary energy, storage change and residual.

The carrier validates the existing F-PM07B/FMR39 identity `residual = storage_change - boundary_energy`. It is copied/restored through the same transaction attempt context as the admitted bottom thermal carrier. It is not committed physical state.

`fmr_execute_multisubstep_sensible_boundary` opts into that carrier only around the same I24 -> I23 -> receipt-owned bottom-energy transaction call. It snapshots the top candidate immediately after the call and clears backend scratch before publishing anything.

## Accepted-route semantics

For one accepted substep, EB-I25 inherits the admitted EB-I24 boundary publication unchanged.

For two or more accepted substeps, EB-I25 requires:

- a ready top candidate covering exactly the requested accepted interval;
- exactly one carrier sample per accepted substep;
- contiguous valid sample intervals;
- complete, finite FMR39 thermal accounting for every sample.

Top conductive energy is the sum of accepted-substep restricted-soil-temperature boundary energies, converted exactly from J/cm2 to J/m2 by `1e4`.

Bottom conductive energy remains the explicit qualified restricted-soil-temperature zero-flux boundary condition. This is a modeled zero, not missing evidence repaired to zero.

Bottom advective sensible energy remains inherited from the accepted receipt-owned bottom-energy publication.

For snow-inactive top liquid transport, external donor temperature may be used only when every accepted top-water sample is inflow or exact zero. Any accepted top-water outflow makes top advective sensible energy unavailable; inflow and outflow are never netted to reuse an external donor temperature. Missing donor temperature remains unavailable. Exact zero transport may be a known zero under the admitted external-liquid-temperature contract.

## Required owner evidence

The owner gate must demonstrate at O0 and O2:

- deterministic accepted external full/half execution with exactly two accepted substeps;
- exactly two top-carrier samples, proving the rejected full trial does not leak;
- accepted top liquid amount equals the two accepted halves only;
- aggregated top conductive evidence is available;
- explicit zero bottom conductive evidence is available;
- receipt-owned bottom advective evidence remains available;
- qualified multi-substep top inflow closes the EB-I22 boundary when all donor evidence is present;
- missing top donor remains unavailable;
- top outflow cannot reuse external donor temperature;
- single-substep output is equivalent to EB-I24;
- rejected transaction publishes nothing;
- O0/O2 semantic output identity.

## Hard nonclaims

EB-I25 does not add or alter Richards, soil-temperature, sensible-enthalpy, or donor-temperature physics. It does not qualify top liquid outflow sensible transport. It does not qualify mixed inflow/outflow top transport. It does not qualify snow/melt thermal provenance. It does not publish a whole-column sensible-energy residual. It does not add radiation, latent heat, vapor energy, freeze/thaw enthalpy, snow phase-change closure, pressure/chemical/salinity enthalpy, or a complete SWAP5 Energy Balance.

Owner qualification is not independent qualification and is not canonical admission.
