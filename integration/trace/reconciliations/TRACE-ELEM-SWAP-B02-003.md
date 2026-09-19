# TRACE-ELEM-SWAP-B02-003 reconciliation

Date closed: 2026-09-19
Prospective result: `CONFIRMED_AND_REPAIRED`
Confirmed case: `TRACE-SWAP-0001`

## Element

Transactional timestep, acceptance, retry and requested-interval publication semantics, selected before detailed inspection as the Batch-02 numerical-scientific convention.

## Scientific and implementation reconciliation

The reviewer page is bound by F-DOC30 to frozen Status-A production baseline `50346642bd565f79134ea17d5462e544b354998c`.

Its two primary frozen owners are:

- `src/transaction/mod_transaction_reference.f90` blob `d5a71a526efaebd82054580c3186f8e3545db331`;
- `src/runtime/mod_canonical_interval_runtime.f90` blob `0b50dda5caf3b73a82561d7b0ba1e92386a08fee`.

Direct source inspection and F-DOC30/F-KT15/F-CI49/F-CI49P evidence agree on:

- checkpoint/candidate separation;
- context restoration on rejection;
- solver, complete-mass and temporal gates before acceptance;
- bounded caller-owned retry handling;
- two-half candidate authority on the external full/half route;
- model-certificate fail-closed semantics;
- private canonical working state distinct from externally committed state;
- one external publication only after full requested-interval completion;
- no partial external publication on failed/no-progress/substep-limit returns;
- accepted-transaction-only mass accumulation.

No new timestep, retry, mass or temporal tolerance is invented by the reviewer page.

## Prospective discrepancy

The scientific/numerical semantics themselves reconciled.

The discrepancy was in the **current authority status** of that reviewer documentation: canonical retained F-DOC30's pre-admission VERIFY status after PR #194 was merged, while the work branch already contained a post-merge CLOSE status documenting the completed admission.

TRACE-SWAP-0001 was registered and frozen before PR/branch chronology was inspected.

## Resolution

Chronology confirmed the mismatch as stale canonical closeout metadata rather than intentional frozen provenance.

The exact existing F-DOC30 closeout status was propagated to the canonical lineage. No production or scientific source changed.

Repair postimage `6d17307d4522f0973e556eafe861c9aa21e71131` passed TRACE run `35438262921` and broad F-GC42 preservation run `35438262905`.

This element remains in the denominator as a confirmed prospective discrepancy, not a null observation.
