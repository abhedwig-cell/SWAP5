# EB-I17 External Bottom Thermal Donor Provider Closure

## Decision

`QUALIFIED_IMPLEMENTATION_BRANCH_CLOSED_PENDING_CANONICAL_ADMISSION`

This disposition is effective only after the EB-I17 qualification workflow succeeds on the exact branch HEAD containing this document.

EB-I17 implements the EB-I16 generic external donor-temperature seam. Requests are created only from the current accepted bottom thermal candidate and contain an evaluation token, sample ordinal, sample interval, read-only candidate transfer context and quadrature time `t1`.

Provider responses contain thermal metadata and provenance only. The accepted candidate remains the authority for water transfer. Complete responses require a finite donor temperature and valid opaque provenance. Unavailable or stale responses leave the complete energy total unavailable. Request/response identity mismatch is rejected.

The existing EB-I15 provider-free evaluator remains available and unchanged in meaning: inward water without an external donor remains incomplete. The new provider-aware entrypoint is opt-in and does not call the provider for local or zero-transfer samples.

No automatic runtime invocation, accepted energy publication, restart field, source-specific groundwater mapping, deep-vadose routing or extra physical solve is introduced by this workunit.

All thirty architecture invariants are addressed in `tests/eb/EB-I17_ARCHITECTURE_AUDIT.json`.

The next boundary is transactional publication of an already-complete candidate energy result after outer acceptance. Governing thermal feedback remains separate later work.
