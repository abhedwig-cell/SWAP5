# TOP03 canonical prerequisite review

Date: 2026-10-01
Status: BLOCKED_BY_DYNAMIC_TOP_TEMPORAL_ACCEPTANCE

Pinned TOP03 head: 66e3e3d098bf0b638058259b8665e17772b298e5.
Pinned canonical: 19f09b818b1bb30c1428919074c00098dbd062bd.
AGENTS.md blob remains 3da9ffe679b8fcde0ccab1fa1311dd6c81e5336b.

The relevant canonical delta since e2d18564383e1350b0b9a68af0eaf668dac784af admits A26 bounded live RFM runtime. Its envelope is unponded, runoff-free flux-controlled operation. The backend delta adds RFM source/top binding and its separate ledger; it does not replace BASE temporal identity or admit imposed external surface head temporal acceptance. TOP03 has not been semantically reconciled onto that new backend; existing local evidence remains scoped to its named source postimage.

An alternative was inspected at the exact canonical ref: src/solver/mod_reference_richards_temporal_indicator.f90, blob 34ba400d5548d92c22bc6dd82a32b65f7a1ddc97. Its boundary gate requires FSI_TOP_MODE_EXPLICIT_FLUX and returns SW_TEMPORAL_INDICATOR_UNAVAILABLE with boundary-envelope-deferred for a dynamic top. It additionally requires fixed_flux_top_boundary_provider_t. Therefore enabling the existing history/certificate mode cannot qualify the imposed-head dynamic provider as currently implemented. Converting its accepted qtop to a fixed forcing before the nonlinear solve would change the hydraulic problem and is not an equivalent workaround.

Historical Actions runs 36915617547 (96a2d1cb) and 36922826825 (485571d4) are both completed/failure. Neither tests the repaired source postimage 4c164b08. No new run was requested.

Required owning deliverable: an explicit transient acceptance contract that covers imposed-head dynamic top, its initial head jump, pressure/water/ponding error measure, finite caller-owned accuracy budget, refinement oracle, and rejected-trial history rollback. Either extend and qualify the model certificate envelope or qualify a bounded external full/half measure. Preserve the existing default-off identity route and hard mass gate. This is a numerical contract, not a receipt or materializer repair.

After that deliverable, resume the normal real TOP03 candidate/receipt gate, qualify full/half interval carrier selection, and reconcile against then-current canonical while preserving A26 and standard macropore paths. No production-admission or closeout claim is made here.
