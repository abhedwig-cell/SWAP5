# F-PERF-CANON01 — post-canonical performance lineage reconciliation

Date: 2026-09-25

Status: `LINEAGE_RECONCILIATION_OPEN`

Canonical root at work-unit start:
`integration/f-ci-canonical@506c36aab6f84b74dffdf5c37fe572c1e0b46610`

Consumer handoff:
F-AHL50 PR #620, status `READY_CANONICAL_OPT_IN_ADMISSION`.

## Purpose

Determine the smallest defensible production lineage that must be admitted before the bounded F-AHL50 six-file direct-retention delta can be recomposed on canonical.

This work unit owns lineage/governance reconciliation. It does not reopen hydraulic representation design and does not bulk-merge research branches.

## Repository-backed lineage

The current chain is not:

canonical -> ZERO-WASTE01 -> PLANVALID01 -> F-AHL50.

There is an earlier production dependency.

Observed ancestry:

1. current canonical: `506c36a...`;
2. PROFILE02-H03 / constitutive-tuple-reuse candidate, PR #600: `91f73a32...`, 73 commits ahead of canonical;
3. PROFILE03-H03-E2E parent: 89 commits ahead of canonical;
4. ZERO-WASTE01 PR #601 head: `f5ba6576...`, 380 commits ahead of canonical;
5. PLANVALID01 PR #610 head: `df664f56...`, 14 commits ahead of ZERO-WASTE01;
6. F-AHL50 PR #620 clean admission head: `2811fda3...`, based on PLANVALID01.

Therefore ZERO-WASTE01 cannot be treated as a self-contained first canonical performance delta.

## Source-scope observations

PR #600 / PROFILE02-H03 is already 73 commits ahead of canonical and changes ten production files, including transaction, kernel, HeadCalc, workspace, solver-contract and serialized-backend sources.

The PROFILE03-H03-E2E parent is 89 commits ahead of canonical and changes the same broad production seam.

ZERO-WASTE01 is 380 commits ahead of canonical and changes 26 production files.

PLANVALID01 is structurally narrow relative to ZERO-WASTE01: its production delta is confined to `src/runtime/mod_fmr_runtime_core.f90`.

F-AHL50 is structurally narrow relative to PLANVALID01: six production files.

## Governance conclusion

A direct canonical merge of PR #601, #610 or #620 is not authorized by this reconciliation.

The unresolved authority question starts before ZERO-WASTE01: which PROFILE02/PROFILE03 production changes between canonical and the ZERO-WASTE parent were independently qualified/admitted and are intended to become canonical?

Until that earlier seam is reconciled, selecting ZERO-WASTE01 as a canonical base would silently admit at least 89 pre-ZERO-WASTE commits and selecting its final head would silently admit 380 commits.

## Required decomposition

Canonical performance admission must be reconstructed in bounded tranches:

### Tranche A — pre-ZERO-WASTE production seam
Reconcile PR #600 and the PROFILE03-H03-E2E continuation against canonical. Identify exact production commits and qualification evidence. Recompose only independently qualified source deltas.

### Tranche B — ZERO-WASTE exact P0
Starting from the admitted Tranche-A postimage, recover the exact admitted ZERO-WASTE production deltas from its closeout, including later large-N groundwater fast paths. Do not replay measurement-only, rejected or rolled-back experiments.

### Tranche C — PLANVALID01
Recompose the admitted exact execution-plan fast path on the admitted ZERO-WASTE postimage. Its source delta is expected to remain narrow.

### Tranche D — F-AHL50
Recompose the six-file opt-in direct-retention delta and replay the F-AHL50 admission suite. Preserve default OFF and the bounded envelope.

## Stop rules

Fail closed if:
- an admitted claim cannot be bound to an exact production commit;
- a source change depends on an unadmitted predecessor;
- a historical branch contains mixed admitted/rejected experiments that cannot be separated;
- canonical preservation requires unrelated source admission.

No branch in this lineage may be bulk-merged merely because all later work depends on it.

## Immediate next task

Reconcile Tranche A first. PR #600 is the first concrete candidate surface, but its 73-commit distance from canonical means its exact production patch must be identified before any canonical mutation.

F-AHL50 remains technically closed while this governance work proceeds.
