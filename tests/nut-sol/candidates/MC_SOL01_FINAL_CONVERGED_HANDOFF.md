# MC-SOL01: final-converged gross receipt propagation contract

Status: implementation design derived from inspected production source, NOT IMPLEMENTED or ADMITTED.
Pinned canonical `7846347e37074028e1db60a9b4dbe3202fa5716e`.

The exact missing handoff is now identified:
1. `src/solver/mod_b110_dynamic_top_boundary_provider.f90` computes `b110_dynamic_top_boundary_result_t` with actual bare soil evaporation, pond evaporation and runoff depth.
2. `src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90` propagates these through dynamic-top evaluation to HeadCalc.
3. `src/legacy/b1_10_port/headcalc.f90` enforces pond conservation with `provider_dynamic_top_result%net_potential_surface_flux`, `state%runots`, and final `state%qtop`.
4. `src/solver/mod_soil_water_solver_contract.f90` exposes `soil_water_solve_result_t`, which contains candidate physical state, top/bottom flux and diagnostics **but no gross top-boundary loss receipt**.
5. `src/runtime/mod_fmr_serialized_reference_backend.f90` subsequently reconstructs net exterior surface exchange for the transaction ledger; accepted substep `fmr_water_flux_substep_trace_t` has pond endpoints and qtop but no gross receipts.

The first correct production modification is therefore on the **converged HeadCalc → soil_water_solve_result_t handoff**, not the SOL store, and not a post hoc computation from `qtop`. An availability-tagged immutable substep receipt must be populated only from the converged final top evaluation, or from source-certified final HeadCalc state, not the last intermediate Newton callback. The receipt must bind t0/t1, gross rain/irrigation/runon, accepted actual surface evaporation and runoff, qtop, pond start/end and the macropore/capacity return mechanism as applicable; no inferred chemistry concentration.

Before it can be propagated to the accepted water trace, prove:
- rejected/full-versus-half candidates never leak gross receipts;
- the solver's final pond balance equals the sum of the receipt's independent gross terms to the existing strict tolerance;
- receipt availability is false for non-dynamic, unsupported or ambiguous routes;
- existing net outer mass ledger is unchanged and equivalent to gross sum for eligible routes;
- fail closed if HeadCalc cannot bind the last *converged* surface result with final accepted state;
- source/byte preservation of existing #1234/#1256/#1257/#1258 and bounded O0/O2 production, rollback, restart tests.

A standalone `surface_gross_receipt_t` in this draft demonstrates consumer balance only; it does not supply the missing final-converged provenance. Historical B1.11 chemical mixing/evaporation order remains unverified. Do not merge PR #1288, do not issue mastercoverage promotion, and do not weaken water-balance tolerance.
