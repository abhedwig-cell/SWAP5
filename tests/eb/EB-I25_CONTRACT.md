# EB-I25 — Accepted two-half trajectory sensible-boundary runtime materialization

## Qualified question

Can the admitted EB-I22/I23/I24 sensible-boundary contracts be materialized over an accepted `TX_TEMPORAL_EXTERNAL_FULL_HALF` trajectory without leaking the discarded full trial, inventing donor temperatures, or changing thermodynamic laws?

## Bounded production change

EB-I25 adds one worker-local top sensible-boundary carrier to the serialized reference backend. The carrier is transaction attempt-context scratch. Per physical advance it records only:

- the advance interval;
- canonical signed top liquid exchange (`+` leaves soil, `-` enters soil);
- the already qualified restricted-soil-temperature boundary energy, storage change and residual.

The carrier validates the existing F-PM07B/FMR39 identity `residual = storage_change - boundary_energy`. It is copied/restored through the same transaction attempt context as the admitted bottom thermal carrier, so discarded full-trial and retry work is removed by rollback. It is not committed physical state.

`fmr_execute_multisubstep_sensible_boundary` opts into that carrier only around the same I24 -> I23 -> receipt-owned bottom-energy transaction call. It snapshots the candidate immediately after that call and clears backend scratch before publishing anything.

## Route semantics

`output%accepted_substeps` counts canonical committed runtime transactions. It is **not** the number of internal accepted transaction advances. An accepted external full/half transaction therefore has `accepted_substeps == 1` while its accepted trajectory consists of exactly two half-trial advances.

For the already admitted model-certificate route with one canonical commit, EB-I25 inherits EB-I24 unchanged.

For `TX_TEMPORAL_EXTERNAL_FULL_HALF`, EB-I25 requires:

- exactly one canonical committed runtime transaction;
- a ready top candidate covering exactly the requested interval;
- exactly two contiguous carrier samples covering the two accepted half advances;
- complete, finite FMR39 thermal accounting for both samples.

The discarded full trial must not appear in the candidate. Multiple outer committed runtime substeps are deliberately not qualified here because the backend candidate is scoped to one serialized `run_trial` call.

Top conductive energy is the sum of the two accepted-half restricted-soil-temperature boundary energies, converted exactly from J/cm2 to J/m2 by `1e4`.

Bottom conductive energy remains the explicit qualified restricted-soil-temperature zero-flux boundary condition. This is a modeled zero, not missing evidence repaired to zero.

Bottom advective sensible energy remains inherited from the accepted receipt-owned bottom-energy publication.

For snow-inactive top liquid transport, external donor temperature may be used only when both accepted top-water samples are inflow or exact zero. Any accepted top-water outflow makes top advective sensible energy unavailable; inflow and outflow are never netted to reuse an external donor temperature. Missing donor temperature remains unavailable. Exact zero transport may be a known zero under the admitted external-liquid-temperature contract.

## Required owner evidence

The owner gate must demonstrate at O0 and O2:

- the already qualified temporal-history physical fixture commits in external full/half mode;
- the route exposes one canonical commit while the carrier contains exactly two accepted half samples;
- the discarded full trial does not leak into the carrier;
- accepted top liquid amount equals the two accepted halves only;
- aggregated top conductive evidence is available;
- explicit zero bottom conductive evidence is available;
- receipt-owned bottom advective evidence remains available;
- qualified two-half top inflow closes the EB-I22 boundary when all donor evidence is present;
- missing top donor remains unavailable;
- top outflow cannot reuse external donor temperature;
- model-certificate output is equivalent to EB-I24;
- rejected transaction publishes nothing;
- O0/O2 semantic output identity.

## Hard nonclaims

EB-I25 does not aggregate multiple outer committed runtime substeps. It does not add or alter Richards, soil-temperature, sensible-enthalpy, donor-temperature, timestep or transaction physics. It does not qualify top liquid outflow sensible transport, mixed inflow/outflow top transport, or snow/melt thermal provenance. It does not publish a whole-column sensible-energy residual. It does not add radiation, latent heat, vapor energy, freeze/thaw enthalpy, snow phase-change closure, pressure/chemical/salinity enthalpy, or a complete SWAP5 Energy Balance.

Owner qualification is not independent qualification and is not canonical admission.
