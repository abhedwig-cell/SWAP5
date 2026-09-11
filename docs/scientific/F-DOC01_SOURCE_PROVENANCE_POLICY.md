# F-DOC01 source provenance policy

Every scientific theory, equation, closure, boundary condition and empirical relation has explicit provenance.

## Provenance classes

- `FIRST_PRINCIPLES_PHYSICS`
- `PEER_REVIEWED_SOURCE`
- `SWAP_TECHNICAL_REPORT`
- `WUR_INTERNAL_REPORT`
- `LEGACY_MANUAL`
- `SOURCE_CODE_RECONSTRUCTION`
- `EMPIRICAL_CALIBRATION`
- `EXPERT_ASSUMPTION`
- `NEW_SWAP5_FORMULATION`

## Source record

At minimum record: title, authors/issuing organisation, publication year/version, persistent identifier or controlled repository locator, accessed/retrieved date for web material, relevant equation/section locator where stable, provenance class, scope, and relationship to the SWAP5 node.

A page number may be stored as a locator but is never the scientific object ID. URLs alone are insufficient for durable authority when a DOI, report number, revision, archive hash or controlled copy is available.

## Authority hierarchy is contextual

First-principles physics can justify a conservation law but not an empirical crop-stress parameterisation. A peer-reviewed paper can support theory but does not prove the software implementation. A SWAP technical report can document historical model intent but may conflict with later code. Source authority is therefore typed, not globally ranked.

## Legacy lineage

Historical SWAP theory is classified as `UNCHANGED_SCIENTIFIC_CONTINUITY`, `STRUCTURALLY_REIMPLEMENTED`, `SCIENTIFICALLY_CHANGED`, `LEGACY_DEFECT_CORRECTED`, `OBSOLETE`, `SOURCE_CODE_RECONSTRUCTION_ONLY`, or `UNRESOLVED_LINEAGE`. Every imported claim states which applies.

No legacy manual or source routine is copied into SWAP5 scientific truth without that lineage assessment.
