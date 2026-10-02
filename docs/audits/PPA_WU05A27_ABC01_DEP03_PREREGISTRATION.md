# PPA-WU05-A27-ABC01-DEP03 preregistration — zero-supply RFM continuation

Date: 2026-10-02
Status: PREREGISTERED_SHARED_BACKEND_DEPENDENCY
Baseline: `41daf2c62f9c74a0310a1443f1cf92000c7565d3`

## Trigger

After DEP01 and DEP02, ABC01 completes RFM C in all continuous-forcing R4/R6 cases, but every event-limited case fails exactly at the first zero-rain interval:
- R1/R2/R3 at step 5 after t=0.04 d;
- R5 at step 4 after t=0.03 d;
- R7/R8 at step 9 after t=0.08 d.

Those failures are solver-path rejections, not admission, temporal or mass failures.

## Source defect

`evaluate_rfm_unponded_activation()` already defines non-positive source handling such that zero source is a valid AVAILABLE activation with zero matrix and preferential rates.

`compose_rfm_unponded_surface_receipt()` then overrides that valid zero-source state by returning `RFM_SURFACE_COMPOSITION_REFERENCE_REQUIRED` for `supply <= 0`.

The live preparer therefore cannot construct a candidate during a dry interval, including a candidate whose only active fast-domain process is release of previously stored terminating-IC water to the matrix.

## Authorized repair

In `compose_rfm_unponded_surface_receipt()`:
- retain `supply < 0` as `REFERENCE_REQUIRED`;
- treat exactly zero supply as a valid AVAILABLE composition with effective, matrix and preferential supply all zero and zero partition residual;
- require the activation to be AVAILABLE before accepting the zero-supply result.

No new surface source is created. Existing RFM storage/release, mass accounting and event-age reset semantics remain authoritative.

Do not alter positive-supply partitioning, ponding/runoff fail-closed behavior, forcing, geometry, benchmark thresholds or retry policy.

## Qualification

Run the same A26/backend preservation and ABC01 postimage. Standard B must remain at least 29/32. C must no longer fail solely at event cessation. Any later C solver, temporal or mass failures remain results, not repair targets.

This is branch-local qualification, not canonical admission.
