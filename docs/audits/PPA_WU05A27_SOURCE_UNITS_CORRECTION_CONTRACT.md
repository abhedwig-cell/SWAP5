# A27 RFM source-unit correction contract

Status: PROPOSED_BOUNDED_REPAIR
Reproduced old postimage: 57eeac0cbe98969f449593047810eb23bbf667d2.

Actual production composer emits endpoint_release/(node_thickness*dt), which the actual A24 wrapper adds unchanged to the Reference provider. HeadCalc residual and flux recurrence consume areic compartment source rates in cm/day, without multiplying by dz. Consequently matrix receipt is release/dz while IC loses release. The existing A23 candidate ledger checks the declared release but not the actual accepted matrix receipt. A26 green checks do not invalidate this independent cross-domain observation.

Repair only the source conversion to endpoint_release/dt. This corrects dimensions for the existing Reference source/sink contract and does not add two-way physics, new state, or broaden surface compatibility. No interface signature changes. The existing volumetric-sounding field name remains for compatibility and is documented as areic at this solver seam. Do not modify the solver to reinterpret all other sources.

Required evidence: actual production composer + actual RFM source wrapper + real Richards measurement, where measured injection is difference in matrix storage minus difference in bottom inflow against a source-free paired trial; corrected receipt must equal IC release, without dz factor. Replay and accepted-origin identity remain required. Rerun composer, live preparer, source-binding and serialized compile preservation gates locally. No canonical admission from a standalone research result.
