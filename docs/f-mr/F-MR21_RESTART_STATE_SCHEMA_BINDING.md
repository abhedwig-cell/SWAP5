# F-MR21 — Restart physical-state schema binding

## Source binding

Candidate under remediation: `dfffd8535b3345b105b2d71537d8149225f35c54`.

Independent F-MQ25 rejected that candidate because `fmr_restore_committed_restart` accepted a decoded `physical_state` whose concrete dynamic type was incompatible with the declared runtime/template identity, then published the reconstructed registry.

## Narrow remediation

This workunit does not change kernel persistence semantics, physics, solver policy, time semantics, parameter ownership, serialization or I/O. It adds a runtime-owned precondition at the MultiSWAP restart boundary.

The existing shared template identity already provides the independent discriminator needed here. `compatible_backend_id` identifies the runtime backend family and `numerical_continuation_layout_id` distinguishes the base committed physical state from the Richards temporal-history continuation state. F-MR21 therefore does not add a second type witness to every restart record and does not enlarge per-column persistent state.

The concrete-type mapping lives in `mod_fmr_restart_state_contract`, outside the kernel and outside the generic committed-restart implementation. For the currently registered serialized-reference backend:

- `FMR_NUMERICAL_CONTINUATION_NONE` requires exactly `fmr_b110_physical_state_t`;
- `FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY` requires exactly `fmr_b110_temporal_indicator_state_t`;
- unknown continuation layouts and unknown backends fail closed.

`mod_fmr_committed_restart` itself remains physics-type agnostic. It asks the runtime contract registry whether the exported or decoded physical state matches the declared template before trusted reconstruction. A synthetically well-formed but unregistered `transaction_state_t` subtype is therefore rejected before any target state is published.

Optional physical state remains governed separately by `optional_state_layout_id`; F-MR21 does not reinterpret that axis as a dynamic-type discriminator.

## Invariants

The remediation preserves compact persistent state, keeps solver scratch absent, leaves immutable parameters external by reference, and keeps restart validation in runtime rather than the kernel. The validation is derived from independently declared template identity rather than from self-identification by the decoded payload. No file format or parser enters the kernel.

The earlier generic F-MR19 negative fixture used an arbitrary synthetic transaction-state subtype as its nominal positive state. That is no longer a valid production-contract witness once concrete state families are explicitly registered. F-MR21 therefore uses a real production B1.10 state as the positive export/restore witness and retains synthetic state only for the malformed-type negative attack.

## Qualification requirement

A follow-up independent F-MQ candidate must rerun the malformed decoded-state hard negative with a real production B1.10 physical state as the positive control, verify whole-registry atomicity, exercise both registered continuation discriminators and unknown-family rejection, and rerun the full committed-boundary restart matrix. No wider restart profile is admitted by this remediation.
