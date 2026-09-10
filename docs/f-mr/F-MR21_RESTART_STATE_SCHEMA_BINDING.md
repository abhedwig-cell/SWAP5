# F-MR21 — Restart physical-state schema binding

## Source binding

Candidate under remediation: `dfffd8535b3345b105b2d71537d8149225f35c54`.

Independent F-MQ25 rejected that candidate because `fmr_restore_committed_restart` accepted a decoded `physical_state` whose concrete dynamic type was incompatible with the declared serialized-reference template, then atomically published it.

## Narrow remediation

This workunit does not change kernel persistence semantics, physics, solver policy, time semantics, parameter ownership, or serialization/I/O. It adds a runtime-owned precondition at the MultiSWAP restart boundary:

1. the declared template/backend remains the authority for the admissible concrete continuation-state family;
2. before export and before trusted reconstruction, the physical state must match that declared family;
3. the current remediation is intentionally bounded to the already qualified restricted serialized-reference profile: no optional physical-state layout and no numerical-continuation history;
4. unsupported or unknown state families fail closed using the existing restart rejection surface;
5. no duplicate type witness or second physical-state payload is persisted.

For the bounded profile this means the state must be exactly the production `fmr_b110_physical_state_t`. A different `transaction_state_t` subtype, including a synthetically well-formed but semantically unrelated subtype, is rejected before any target state is published.

## Invariants

This preserves compact persistent state, keeps solver scratch absent, leaves immutable parameters external by reference, and keeps restart validation in runtime rather than the kernel. The validation is derived from declared template/backend identity rather than from self-identification by the decoded payload.

## Qualification requirement

A follow-up F-MQ candidate must rerun the malformed decoded-state hard negative with a real production B1.10 physical state as the positive control, plus the full committed-boundary restart matrix. No wider restart profile is admitted by this remediation.
