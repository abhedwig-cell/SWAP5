# TRACE-ELEM-SWAP-B03-003 reconciliation

Date closed: 2026-09-19
Prospective result: `CONFIRMED_AND_REPAIRED`
Confirmed case: `TRACE-SWAP-0003`

## Element

Soil-hydraulic parameter provenance, selected before detailed inspection as Batch-03 SWAP E03.

## Scientific/provenance reconciliation

The reviewer page and F-DOC33 authority matrix consistently separate:

- exact B1.10 internal pointer aliases;
- exact model-dependent `paramvg` to `cofgen` activation rules;
- bounded model-specific supplemental evidence for rows 17:21;
- unresolved original user-facing parser keywords and units where direct frozen binding is absent.

The page explicitly does not infer missing units or parser names from conventional Mualem-Van Genuchten notation.

## Prospective discrepancy

The provenance content itself reconciled.

The discrepancy was the current authority status: canonical retained F-DOC33's pre-admission VERIFY checkpoint after PR #200 merged, while the owner branch contained a later explicit CLOSE/DOCUMENTATION_ADMITTED_AND_CLOSED status.

TRACE-SWAP-0003 was frozen before the PR/branch chronology was inspected.

## Resolution

The exact existing F-DOC33 post-merge closeout object was propagated to the canonical lineage.

Repair head `7910d1410e4639766304801143505e0ffd0d3926` passed TRACE run `35439595539` and broad F-GC42 preservation run `35439595565`.

No provenance claim or scientific semantics changed.

This element remains in the denominator as a confirmed prospective discrepancy.
