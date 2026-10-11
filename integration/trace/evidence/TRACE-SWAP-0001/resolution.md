# TRACE-SWAP-0001 resolution

Date: 2026-09-19
Outcome: `CONFIRMED_AND_CLOSED`
Disposition: `DOCUMENTATION_CORRECTED`
Regression counterfactual: `REGRESSION_NOT_APPLICABLE`

## Confirmed discrepancy

Current canonical contained the admitted F-DOC30 transactional reference, but `integration/f-doc/F-DOC30_STATUS.json` still represented the pre-admission state:

- `phase=VERIFY`;
- exact status-head rerun pending;
- guarded admission still listed as the next action.

PR #194 had in fact already been merged.

## Chronology

The F-DOC30 sequence is reconstructable:

1. content head `c86f17131f4757d35ef33b77d1fd2d7b23050d13` passed Documentation run `35277790693`;
2. admission/status head `6258bfa2302fd6a152b9252389dde08547317924` passed exact-head Documentation run `35277873123`;
3. PR #194 merged that head as canonical merge `8064b092c428fdd84b066dfcfedba43a01cb4ad8`;
4. the work branch then wrote final closeout head `608015a24378ffcceaf713850a2daf528dd8190a`;
5. that final status records `phase=CLOSE`, `DOCUMENTATION_ADMITTED_AND_CLOSED`, the exact admission head and the merge commit;
6. the final closeout status was never propagated back to canonical.

There is no immutable authoring-freeze contract assigning the canonical VERIFY status a deliberate permanent provenance role.

## Scientific consequence

The demonstrated consequence is interpretative.

A reviewer using current canonical could conclude that F-DOC30 still awaited exact-head verification or admission even though its PR had already been admitted.

The underlying transaction semantics were not in conflict:

- frozen transaction source blob `d5a71a526efaebd82054580c3186f8e3545db331`;
- frozen canonical-runtime blob `0b50dda5caf3b73a82561d7b0ba1e92386a08fee`;
- F-KT15 owner qualification;
- F-CI49 canonical admission;
- F-CI49P post-promotion reconciliation;
- reviewer-facing transaction description.

No physical, numerical, mass, solver or state-trajectory discrepancy was found.

## Regression counterfactual

`REGRESSION_NOT_APPLICABLE`.

The pre-existing Documentation workflow on `6258bfa...` ran before the merge and correctly validated the pre-admission status. The inconsistency arose only after the merge, when the separately authored post-merge closeout status was not propagated to canonical.

No pre-existing post-merge status-synchronization oracle was identified.

The TRACE registry did fail closed during this resolution when the candidate was marked confirmed before its case record existed, showing that current TRACE bookkeeping itself rejects incomplete confirmed-case state.

## Repair

The repair copies the already-existing authoritative F-DOC30 post-merge closeout status exactly onto the current canonical lineage.

No reviewer prose, production source, reference source, tests, solver behavior, transaction behavior, retry policy or tolerance is changed.

Repair postimage:

`6d17307d4522f0973e556eafe861c9aa21e71131`

Qualification:

- TRACE research integrity run `35438262921`: success;
- F-GC42 live whole-window preservation run `35438262905`: success.

## TRACE significance

This is the first confirmed prospective SWAP TRACE discrepancy.

It is an authority-state propagation failure rather than a scientific-equation defect. That distinction matters: the scientific transaction contract was already consistent, but the repository's current canonical metadata misrepresented whether the documentation workunit was still pending or already admitted.
