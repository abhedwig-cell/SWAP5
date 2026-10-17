# MC-SOL01 gross producer discovery and next production boundary

Canonical inspected: `7846347e37074028e1db60a9b4dbe3202fa5716e`.

**Finding:** The missing gross water-flow quantities are **already computed during dynamic top-boundary solution**, contrary to treating them as absent from hydraulics altogether.

- `src/solver/mod_b110_dynamic_top_boundary_provider.f90`: `b110_dynamic_top_boundary_result_t` contains `bare_soil_evaporation_cm_per_day`, `ponded_water_evaporation_cm_per_day`, `runoff_depth_cm`, `actual_top_flux_cm_per_day`, `candidate_ponding_depth_cm`, `net_potential_surface_flux_cm_per_day`.
- `src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90`: copies those calculated outputs to the solver-facing dynamic boundary result, including `result%bare_soil_evaporation`, `result%ponded_water_evaporation`, `result%runoff_depth`, and `result%runoff_resolved=.true.`.
- `src/legacy/b1_10_port/headcalc.f90`: consumes `provider_dynamic_top_result`; the dynamic-top pond check uses `pond-pondm1-net_potential_surface_flux*dt+runots-qtop*dt`. Actual runoff `state%runots` is taken from `provider_dynamic_top_result%runoff_depth`. The solver owns and validates the physical pond balance, including gross loss representation.
- `src/runtime/mod_fmr_serialized_reference_backend.f90`: its committed transaction mass ledger derives only net external exchange, then `append_accepted_water_flux_substep` emits qtop/pond endpoints without actual gross losses.

**Critical distinction:** The solver-facing dynamic boundary result may be evaluated many times during Newton iteration and a rejected trial. Merely copying its latest fields from an evaluation into the accepted trace is unsafe. The necessary change is to carry the **final converged candidate's** water-owner surface receipts through the accepted physical result, with same trial lineage and time interval, without re-evaluation or recomputation from net qtop. Then assert water identity using the actual gross supply and actual losses. Only after that can SOL consume the receipt, using the existing matrix companion pond mass and joint publish/restart.

**Limits:** This is source-level authority mapping, not an implemented/compiled production change. Gross runon/rain/irrigation are forcing values, while evaporation and runoff are actual model outputs; their association with precisely the accepted substep must be proved in the ownership change. Production interface/solver result and rollback contracts have not yet been inspected to sufficient depth to authorize the patch. Existing PR #1288 remains experimental and unmerged. This narrows the previously named blocker from 'missing physical gross computations' to 'missing safe final-converged accepted receipt propagation'.
