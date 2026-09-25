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


## Tranche-A refinement: PROFILE01 is not the missing production admission

Further repository reconciliation narrows the pre-ZERO-WASTE problem.

PR #599 / F-PE-PROFILE01 is explicitly observation-only. Its final closeout states `PRODUCTION_REPAIR = NONE` and sends H03 to a separate repair branch. Therefore the 59-commit PR branch must not be admitted as a production tranche.

PR #600 / F-PE-PROFILE02-H03 gives the exact split point:
`0b373c6cdaed53e26a1acb917f096bf20256f12a`.

Its own final closeout states that, relative to that split point, the only production-source change in the H03 repair is:
`src/legacy/b1_10_port/headcalc.f90`.

Direct repository compare confirms:
- split point -> PR #600 head: 15 commits;
- production source delta: exactly one file, `headcalc.f90`;
- 11 added / 3 deleted lines in that file.

So the H03 repair itself is bounded and separable.

However, the split point is already 58 commits ahead of current canonical and differs in ten production files. Those changes predate the PROFILE01 observation work. They are the actual unresolved predecessor authority.

This corrects the earlier broad statement that PR #600 itself was a ten-file production candidate. It is not. The ten-file difference is inherited ancestry; the H03 repair is one-file bounded.

## Updated Tranche-A decomposition

A0. Reconcile `integration/f-ci-canonical@506c36a...` -> PROFILE01 split point `0b373c6c...`.
This is now the earliest unresolved production lineage.

A1. Treat PR #599 as evidence/observation only; do not admit its branch wholesale.

A2. Recompose the qualified PR #600 H03 repair as a one-file HeadCalc delta only after A0 is resolved.

A3. Reconcile PROFILE03-H03-E2E. Determine whether it contains production repair or measurement only before using it as the ZERO-WASTE parent.

Only after A0-A3 may ZERO-WASTE01 be decomposed into its admitted exact-P0 production patches.

## Current blocker

`A0_PRE_PROFILE01_PRODUCTION_AUTHORITY_UNRESOLVED`

This is now the first concrete canonical-governance question. F-AHL50 and PLANVALID01 do not need reopening while A0 is resolved.


## A0 provenance interpretation

The ten-file A0 source surface is not evidence that PROFILE01 itself changed production. PROFILE01 explicitly reports no repair. The source state at its split point is inherited production authority.

A key provenance anchor is F-KT22:
- PR #147 is an historical current-canonical recomposition surface;
- it explicitly says its base was then-current canonical `64937452...`;
- it overlaid already-qualified F-KT22 source while preserving admitted EB-I25 FMR changes;
- it was not itself canonical admission;
- later F-CI91 preservation records F-KT22 as the only relevant dependency change in that chain and states the final independent F-CI81 qualification had already been performed after it.

This establishes that at least part of the A0 ten-file seam belongs to previously qualified transaction/runtime evolution, not performance experimentation.

The present canonical head `506c36a...` is much later than the historical F-KT22 base, so the remaining discrepancy cannot be resolved by treating PR #147 as an admission patch. The correct task is current-postimage provenance reconciliation: identify which A0 blobs are already represented by admitted capabilities and which are genuinely unadmitted branch drift.

## A0 file classification target

The ten production files are now grouped by authority family:

Transaction/runtime state:
- `src/transaction/mod_transaction_reference.f90`
- `src/kernel/mod_kernel_transactions.f90`
- `src/runtime/mod_a23bu_worker_execution_context.f90`
- `src/runtime/mod_canonical_contracts.f90`
- `src/runtime/mod_canonical_interval_runtime.f90`

Reference solver seam:
- `src/legacy/b1_10_port/headcalc.f90`
- `src/solver/mod_reference_richards_workspace.f90`
- `src/solver/mod_soil_water_solver_contract.f90`
- `src/adapter/mod_reference_richards_legacy_binding.f90`
- `src/runtime/mod_fmr_serialized_reference_backend.f90`

The next discriminator is byte/provenance matching against later admitted current-canonical capability records, not a blind replay of the 58 commits.

A0 remains open, but its problem is now classified as `INHERITED_PRODUCTION_PROVENANCE_RECONCILIATION`, not `UNKNOWN_PERFORMANCE_PATCH`.
