# MC-SOL01 accepted gross-flux provenance at actual producer

Pinned canonical: `7846347e37074028e1db60a9b4dbe3202fa5716e`.
The affected source is `src/runtime/mod_fmr_serialized_reference_backend.f90`.

In `fmr_serialized_advance`, the accepted water-transaction ledger computes
`surface_external_exchange_cm = pond_end - pond_start - solve_result%top_flux*dt + macropore_pond_accepted_cm`
for dynamic top. This is a **net external exchange** designed to close the transaction mass ledger, not independent rain/irrigation/runon/evaporation/runoff receipts. `append_accepted_water_flux_substep` is subsequently called with the solver request and result, and places `top_flux`, `bottom_flux`, `pond_start_cm`, `pond_end_cm` and soil arrays in the accepted trace. It does not receive the process-resolved gross fluxes.

Earlier in the same producer, Black evaporation calls
`bind_b110_dynamic_top_boundary_solver_provider` with separate typed precipitation,
irrigation, snowmelt, runon, bare-soil demand, pond evaporation potential, pond max,
runoff resistance/exponent and conductivity. These are **forcing / potentials**;
they are not the *accepted actual* evaporation/runoff exchange produced by the numerical substep.
Exposing them unmodified as accepted actual fluxes would be a false physical claim.

## Consequence

Implementing only a few new fields in the accepted trace or copying forcing requests
cannot close MC-SOL01. The true hydraulic dynamic-top calculation must emit a
validated gross exchange receipt from its converged candidate and accepted water
state, with consistent sign, unit, temporal scope and availability flags. The
outer model transaction ledger must conserve the sum of these exchanges,
including macropore pond transfer and any capacity return, before chemistry
can read it. Keeping the existing net outer ledger and creating a second,
independently guessed gross ledger is forbidden.

The current candidate `surface_gross_receipt_t` and local balance tests specify
only a *consumer-side invariant*. They are not provenance for actual hydraulics.
No production modification or admission is made by this finding. The next
code owner is the real dynamic-top boundary / HeadCalc accepted-substep receipt
producer, not the standalone MC-SOL01 candidate module.
