# PPA-WU05-A27-CANREC01 result — MIGMAC01 storage allocation guard

Date: 2026-10-02
Status: QUALIFIED_BRANCH_REPAIR_CANDIDATE
Canonical admission: NO

Current canonical MIGMAC01 introduced an unsafe compound condition in `fmr_serialized_storage()` that inspected `self%macropore_config%matrix_area_fraction` in the same `.and.` expression that tested allocation of `self%macropore_config`.

Fortran does not guarantee short-circuit evaluation. Run `36999130548` with debug symbols locates the resulting base-arm segfault at `mod_fmr_serialized_reference_backend.f90:3326`.

The repair nests the allocation guards. The MIGMAC01 area-weighted matrix-storage expression is unchanged when the area-fraction vector exists; ordinary full-area matrix storage is unchanged otherwise.

Confirmation:
- diagnostic run `36999253235`: ABC execution completes, rc=0;
- final PERF02 owner run `36999473010`: A26 live, A27 backend, A8, PROFILE and full ABC all pass.

This is a source-backed current-canonical defect repair candidate discovered during A27 reconciliation. A27 does not canonically admit it.
