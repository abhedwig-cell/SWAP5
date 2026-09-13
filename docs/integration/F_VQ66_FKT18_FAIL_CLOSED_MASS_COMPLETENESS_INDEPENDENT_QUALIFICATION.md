# F-VQ66 — F-KT18 Fail-Closed Mass Completeness Transaction Admission Independent Qualification

## Decision

`QUALIFIED_FKT18_FAIL_CLOSED_MASS_COMPLETENESS_TRANSACTION_ADMISSION`

Recommendation: `READY_FOR_CANONICAL_ADMISSION`.

This is an independent verification workunit. It changes no production source and makes no 100% completion claim.

## Numbering and provenance

At branch creation the live F-VQ namespace already contained F-VQ01 through F-VQ65 and no F-VQ66 branch. F-VQ66 was therefore the first free number and was created as:

`qualification/f-vq66-fkt18-fail-closed-mass-completeness-independent-qualification`

from the immutable qualified candidate source rather than the moving owner tip.

During the later CI checkout, other concurrently-created branches containing F-VQ66/F-VQ67 requalification names were visible. They appeared after this workunit had already reserved F-VQ66; this workunit did not overwrite or reuse an existing branch.

Owner authority rechecked live:

- owner branch: `work/f-kt18-fail-closed-mass-completeness-transaction-admission`
- owner authority: `66fd08ca96d8be69cf6f996202e21ce624db526b`
- owner tree: `7e23da589a93d9ab9e613ca9cbeb2985b1366545`
- immutable qualified candidate: `623e633b1f8451bd849f590f796806f11e1ecbdf`
- candidate tree: `47826cb69e04c46b8739bcf953ac26db80b5ff3e`
- production remediation commit: `29af8fa9b62f3b87fe8703f2a1726ba8daad1b44`

Finding authority:

- F-KT17: `c14bd8c7f67e015bf1bd4bdcfa88eb97470194da`
- tree: `fbf1fe0b6cc853de5ce375830a98251753a598b3`
- finding: `F-KT17-G01`
- primary class: `MASS_GAP`
- secondary class: `IMPLEMENTATION_GAP`

## Independent source inspection

The exact immutable candidate source was inspected, especially `src/transaction/mod_transaction_reference.f90` and the directly involved kernel transaction path.

Both generic transaction admission routes are fail-closed:

1. External full-versus-two-half admission requires complete storage/trial accounting, a zero missing-contribution mask, finite relevant storage/mass/residual quantities and a residual within tolerance before an accepted state can be published.
2. Model-certificate admission likewise requires complete accounting, zero missing mask, finite relevant quantities and only then the residual-tolerance criterion. Rejection stays on the existing bounded retry/rollback path.

`src/kernel/mod_kernel_transactions.f90` materializes a candidate only after the canonical runtime reports successful completion. An incomplete-ledger transaction therefore cannot reach a ready kernel candidate; an explicit attempt to commit the invalid candidate is rejected.

One non-blocking diagnostic nuance was observed: the model-certificate route can populate `accepted_mass_residual` with the calculated residual before the final mass gate has accepted the trial. This field assignment does not make the trial accepted: rejection status, zero commits, unchanged committed state and absence of candidate materialization remain authoritative. F-VQ66 therefore did not invent a sentinel contract for that diagnostic field.

## Independent attack matrix

Decisive qualification evidence was produced on exact F-VQ66 evidence head:

`6da84c638de66810fb53371d35be559ad4e52eb8`

Workflow run `34763464602`, Ubuntu 24.04.5, GNU Fortran 13.3.0, both `-O0` and `-O2`.

Attack job `103740198164` independently verifies:

- zero residual + incomplete accounting -> reject, on both admission routes;
- complete flag with nonzero missing-contribution mask -> reject;
- complete + zero mask + finite + in-tolerance residual -> accept;
- complete + residual outside tolerance -> reject;
- NaN mass term -> reject;
- positive infinity mass term -> reject;
- rejected trial leaves committed physical state unchanged;
- repeated retry does not physically accumulate rejected trial state;
- retry exhaustion remains fail-closed;
- incomplete accounting cannot materialize or commit a kernel candidate end-to-end;
- normal complete-ledger path remains accepted;
- alternative solver/service-style incomplete accounting remains rejected;
- O0/O2 oracle output is deterministic and identical.

Final markers include:

- `FVQ66_FKT18_INDEPENDENT_ATTACK_MATRIX=PASS`
- `FVQ66_KERNEL_INCOMPLETE_CANNOT_MATERIALIZE_OR_COMMIT_CANDIDATE=PASS`
- `FVQ66_GNU_FORTRAN_O0_O2_DETERMINISTIC_EQUIVALENCE=PASS`
- `FVQ66_FKT18_INDEPENDENT_GATE=PASS`
- `FVQ66_PRODUCTION_SOURCE_CHANGED_BY_VQ=NO`

## Preservation

Preservation job `103740198088` on the same exact head and compiler/build modes passed:

- `FVQ66_FKT15_SOLVER_SERVICE_REFERENCE_MODEL_PRESERVATION=PASS`
- `FVQ66_FKT15R_CURRENT_RECOMPOSED_TRANSPORT_SURFACE=PASS`
- `FVQ66_FKT16_STATE_PERSISTENCE_RESTART_PRESERVATION=PASS`
- `FVQ66_SERIALIZED_MULTISWAP_PRESERVATION=PASS`
- `FVQ66_GENERIC_TIME_ROLLBACK_RETRY_RESTART_MASS_TRANSPORT=PASS`
- `FVQ66_PRODUCTION_PARALLEL_RUNTIME_PRESERVATION=PASS`
- `FVQ66_FVQ64_PREDICTOR_CORRECTOR_PRESERVATION=PASS`
- `FVQ66_CURRENT_PRESERVATION_GATE=PASS`

Compiler warnings observed during the preservation builds are not qualification failures and were not introduced by F-VQ66. They include existing real-equality, unused-dummy, possible HeadCalc uninitialized-value and impure-function evaluation warnings.

## Current-canonical compatibility

Current canonical was rechecked live after the decisive qualification run:

- `integration/f-ci-canonical@267f2a6ec61f78d3ba4ce75b3e5a7fdc08479135`
- tree `a3f9f82e62337569edb3615c3a47c2df9101ee81`

The two directly relevant admission-surface blobs exactly match the immutable F-KT18 candidate:

- `src/transaction/mod_transaction_reference.f90`: `d5a71a526efaebd82054580c3186f8e3545db331`
- `src/kernel/mod_kernel_transactions.f90`: `c7c5b7d3357e4e6739c8f647d6232baca45563e6`

Classification:

`CURRENT_CANONICAL_ADMISSION_SURFACE_EXACT_BLOB_MATCH_WITH_RELEVANT_PRESERVATION_GREEN`

This is deliberately narrower than a claim that all of current canonical has been globally requalified. The fresh F-VQ66 authority should be reconciled through the canonical-admission process; because the exact production blobs are already present on current canonical, canonical admission should prefer provenance/evidence reconciliation rather than blindly replaying the production patch.

## Architecture and non-claims

Invariant 13, absolute mass conservation, passes this independent qualification for the F-KT18 admission surface. Transactionality, generic time, restart, MultiSWAP, parallel runtime and predictor/corrector preservation also remain green on the tested dependency surfaces.

F-VQ66 introduced no kernel API redesign, physics change, solver change, runtime production change, ledger redesign, tolerance relaxation or reverse-physics rollback.

Production source changed by F-VQ66: **NO**.

This workunit does **not** claim `QUALIFIED_KERNEL_TRANSACTIONS_GENERIC_TIME_MASS_V1_100_PERCENT_COMPLETE` and does **not** claim whole-program SWAP5 completion. Such a completion determination, if applicable, belongs after canonical admission/reconciliation and current-canonical preservation under the frozen completion model.
