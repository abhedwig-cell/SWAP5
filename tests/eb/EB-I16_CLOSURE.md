# EB-I16 External Bottom Donor-Temperature Contract Closure

## Decision

`DESIGN_FROZEN_NO_PRODUCTION_IMPLEMENTATION`

This closure disposition becomes effective only when the `EB-I16 external donor contract` workflow succeeds on the exact branch HEAD containing this document. A green run on an earlier SHA is supporting evidence only.

EB-I16 closes the design question left open by EB-I15: how external liquid-water donor temperature may enter bottom sensible-energy accounting without creating a second water authority or teaching SWAP about MODFLOW, deep-vadose routing, tile composition or another source system.

The frozen seam is request-driven and candidate-scoped. The evaluator derives a request from the current accepted EB-I13 sample only when the donor is external and the accepted outward transfer is strictly negative. The provider supplies only thermal metadata and provenance. The candidate remains the authority for `Q_i`, sample order and interval partition.

For the current EB-I14 reference discretization, the external donor temperature is requested at the accepted sample quadrature point `t1`. Source-side interpolation or state reconstruction belongs to the external adapter/coupler and requires its own qualification. SWAP never silently invents that mapping.

Any absent, unavailable, nonfinite, stale or identity-mismatched external response makes complete bottom sensible energy unavailable. There is no local-temperature fallback, zero-enthalpy fallback, previous-value fallback or default external temperature.

No production source is changed in EB-I16. No accepted energy record is committed or published. No new persistent state or restart field is introduced. No physical solve is added. The existing groundwater head/flux contract and mass ledger remain untouched.

`tests/eb/EB-I16_ARCHITECTURE_AUDIT.json` records explicit PASS/PRESERVED disposition for all thirty SWAP architecture invariants.

The next implementation boundary is a narrow generic provider seam plus an EB-I15 evaluator extension that consumes a valid live provider response for inward samples. That later workunit must still leave accepted-energy commit/publication as a separate transactional boundary unless it independently qualifies that lifecycle.
