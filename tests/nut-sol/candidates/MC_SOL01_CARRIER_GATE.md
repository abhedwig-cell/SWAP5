# MC-SOL01 accepted-carrier gate, 2026-10-17

At pinned canonical `aa73ca4350eaa715b2ae42655f1073caeffd18cb`, the actual accepted water substep carrier `fmr_water_flux_substep_trace_t` in `src/runtime/mod_fmr_serialized_reference_backend.f90` provides `t0/t1`, `top_flux/bottom_flux`, `pond_storage_available`, `pond_start_cm/pond_end_cm`, and soil/macropore/root/drainage arrays. It does NOT provide separately accepted **gross evaporation, runoff, runon, rain and irrigation per substep**. These are not reconstructable uniquely from a net top flux and pond endpoints.

The admitted joint application `src/runtime/mod_fmr_b111_pond_joint_application.f90` rejects Black/Boesten evaporation for this route. `src/process/mod_b111_persistent_pond.f90` enforces exactly `depth_end-depth_begin=(rain+irrigation+qtop)*dt`. Extending solely the chemical owner with runoff or evaporation would violate its accepted water contract. The independent `tests/nut-sol/candidates/check_surface_loss_carrier.py` is a **fail-closed static prerequisite check**; `BLOCKED_EXPECTED` is a correct non-admission outcome and not a numerical PASS.

## Ownership decision

A future water-owner change must first supply independently accepted gross loss/source receipts with exact substep chronology. Shared carrier changes and cross-workstream state ownership require separate contract approval and owner qualification. Only then adapt the existing `mod_fmr_b111_pond_solute_route` and sole matrix companion `pond_mass` using the accepted trial/commit and V2 restart contract; do not create a competing owner or sidecar. Preserve admitted #1234/#1256/#1257/#1258. TOP03 #956 remains unmerged research. Historical SWAP 4.3.1 chemistry/ordering remains unverified; zero-loss existing behavior is the preservation reference.

This note does not claim execution of the static preflight or new SWAP5 O0/O2 production runs. Canonical merge and mastercoverage promotion remain forbidden for PR #1288.
