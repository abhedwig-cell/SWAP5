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


## A0 resolved by byte-equivalent admitted postimage

A decisive repository comparison resolves A0.

Compare:
`integration/f-ci81-rossfast-application-composition-admission`
->
PROFILE01 split point `0b373c6cdaed53e26a1acb917f096bf20256f12a`.

Result:
- split point is 2204 commits ahead in history;
- **zero `src/**` file differences**.

Compare the same F-CI81 authority to current canonical:
- current canonical is 2146 commits ahead;
- **zero `src/**` file differences**.

Therefore the ten-file difference observed between current canonical and the PROFILE01 split point is not an unqualified semantic production delta. Both postimages are source-equivalent to the independently qualified/admitted F-CI81 production authority, while current canonical has later history/governance divergence.

This is stronger than commit-history inference: the complete production source surface is byte-equivalent at the relevant authority comparison.

### A0 decision

`A0_PRE_PROFILE01_PRODUCTION_AUTHORITY = RESOLVED_SOURCE_EQUIVALENT_TO_F_CI81`

No A0 production patch is required.

No 58-commit replay is authorized or needed.

The apparent current-canonical -> split-point source drift is a branch/history artifact relative to the named canonical ref, not a missing production capability that must be re-admitted.

## Updated admission chain

The bounded reconstruction can now start after A0:

1. A0: no-op by source equivalence to F-CI81 authority;
2. A1: PROFILE01 observation only, no production patch;
3. A2: PROFILE02-H03 one-file `headcalc.f90` qualified repair;
4. A3: reconcile PROFILE03-H03-E2E production scope;
5. B: recompose only admitted ZERO-WASTE01 exact-P0 patches;
6. C: PLANVALID01 one-file runtime-core delta;
7. D: F-AHL50 six-file opt-in delta.

The next active discriminator is A3.


## A3 resolved: PROFILE03-H03-E2E is measurement-only

Direct compare from PR #600 qualified H03 head `91f73a32...` to `work/f-pe-profile03-h03-e2e` shows:
- 16 commits ahead;
- only workflows, performance documentation and `tests/fpe/**`;
- **zero `src/**` changes**;
- zero `reference/**` changes.

Therefore PROFILE03-H03-E2E contributes no production delta.

### A3 decision

`A3_PROFILE03_H03_E2E = MEASUREMENT_ONLY_NO_PRODUCTION_ADMISSION`

The production parent for ZERO-WASTE01 is semantically the PR #600 H03 production postimage plus measurement-only history.

## Tranche-A closure

Tranche A is now decomposed completely:

- A0: no production patch required; source-equivalent to F-CI81 authority;
- A1 PROFILE01: observation only;
- A2 PROFILE02-H03: exactly one qualified production file, `src/legacy/b1_10_port/headcalc.f90`;
- A3 PROFILE03-H03-E2E: measurement only.

Thus the only production capability that must be carried forward from Tranche A is the bounded H03 HeadCalc repair.

Next active work is Tranche B: decompose ZERO-WASTE01 into admitted exact-P0 production patches and exclude rejected/rolled-back/measurement-only experiments.


## Tranche-B decomposition rule

ZERO-WASTE01 is a long-lived branch with 291 commits after the measurement-only PROFILE03 parent and 24 changed production files. The branch must not be admitted by final-tree diff alone.

The authoritative closeout provides the admission filter.

### Explicitly admitted late large-N capabilities

The closeout names exactly five admitted large-N groundwater-context P0 capabilities:

- `GWPLAN01 = ADMITTED_EXACT_P0_LARGE_N_STRUCTURAL_FAST_PATH`;
- `GWTOPO01 = ADMITTED_EXACT_P0_LARGE_N_STRUCTURAL_FAST_PATH`;
- `GWCTX01 = ADMITTED_EXACT_P0_LINEAR_HANDLE_UNIQUENESS_PROOF`;
- `GWCTX03 = ADMITTED_EXACT_P0_COMPACT_CONTEXT_CELL_VIEW`;
- `GWVIEW01 = ADMITTED_EXACT_P0_DIRECT_CONTEXT_VIEW_EXPORT`.

These are eligible for bounded recomposition, subject to exact source-patch recovery and preservation replay.

### Explicit exclusions from recomposition

The same closeout explicitly rejects or withholds several explored changes:

- H-DIR04 `move_alloc` ownership transfer: rolled back;
- persistent groundwater-forcing reuse candidates: rejected without a generation contract;
- initial full-constitutive replacement by K+C: rejected because slower;
- H17A request/result adapter-vector reuse: measurement only / low priority;
- directional attempt-context removal: rejected as not pure waste;
- fresh full/half transaction states: retained as required.

These must not appear in a canonical ZERO-WASTE reconstruction even if historical commits exist on the branch.

### Important branch-history rule

The ZERO-WASTE final tree also contains production evolution needed by later qualified application/coupling gates. Presence in the final tree is not equivalent to ZERO-WASTE admission.

For every candidate patch, canonical recomposition requires both:
1. a closeout/admission classification;
2. an exact source change attributable to that capability.

If either is missing, the patch remains provenance-pending.

## Tranche-B current state

`B_ZERO_WASTE_ADMISSION_FILTER = ESTABLISHED`

`B_EXACT_PATCH_RECOVERY = IN_PROGRESS`

The next task is exact patch recovery for the admitted capabilities, beginning with the small structural groundwater fast paths and the original H01 duplicate-work removal. This is safer than copying the 24-file final ZERO-WASTE tree.


## Tranche-B production authority split

The ZERO-WASTE closeout itself provides a critical exact boundary:

- production-behavior source head: `a03c964c3120d816774032a06a421fd1e85b1835`;
- later H17A head: explicitly measurement-only.

Therefore the core H03 / production-bootstrap P0 reconstruction must bind to `a03c964...`, not to the final ZERO-WASTE branch head.

Direct compare PROFILE03 measurement parent -> `a03c964...` shows 241 commits and 20 production files. This is still too broad for blind admission, but it removes the later large-N groundwater-context tranche from the core P0 source authority.

The later GWPLAN01/GWTOPO01/GWCTX01/GWCTX03/GWVIEW01 changes are separately admitted and must be reconstructed as a second ZERO-WASTE subtranche.

### B1 — core production-bootstrap P0

Authority: `a03c964...`.

Qualified removals/reuse are exactly those enumerated in the closeout:
- all full Reference workspace resets on the hot path;
- overwrite-before-read scratch clears;
- TRIDAG capture resize suppression;
- accepted-direction zero-vector/copy suppression;
- stable-owner registry validation suppression;
- execution-order reuse;
- planned-route template lookup reuse;
- indexed receipt handling;
- unused serialized diagnostics/concurrency bookkeeping suppression;
- parameter allocation/preprocessing/compatibility/copy reuse under immutable authority;
- demand-specialized constitutive evaluation;
- inactive attempt-context skip;
- workspace-owned state-binding capacity reuse.

This is a composite exact-P0 postimage and must be replayed as such unless smaller independently qualified checkpoints can be recovered.

### B2 — large-N groundwater context

Authority: final ZERO-WASTE postimage after the separately admitted five-capability tranche:
GWPLAN01, GWTOPO01, GWCTX01, GWCTX03, GWVIEW01.

These source changes are structurally localized in:
- `mod_groundwater_application_plan.f90`;
- `mod_groundwater_topology_composition.f90`;
- `mod_fmr_groundwater_application_context.f90`;
- `mod_fmr_groundwater_application_c_api.f90`.

Any additional final-tree changes outside those named capability patches require separate provenance and are not admitted merely by association.

## Reconstruction strategy

The safest canonical reconstruction is now:

1. establish an A2 H03 postimage on the source-equivalent canonical production authority;
2. recompose B1 as the qualified `a03c964...` P0 postimage, with exact physical/reference gates;
3. layer B2 as five separately named large-N fast paths;
4. then PLANVALID01;
5. then F-AHL50.

This avoids treating H17A measurement work or rejected ZERO-WASTE experiments as production authority.


## B1 recomposition qualification

Execution PR: #622.

B1 was recomposed from current canonical using the ZERO-WASTE production-behavior authority `a03c964...`.

Initial replay exposed one genuine dependency-closure omission:
`mod_kernel_transactions` consumed the B1 diagnostics fields `workspace_full_resets` and `workspace_zeroed_bytes`, while the recomposition still had older canonical contracts. The exact B1 `mod_canonical_contracts` and `mod_canonical_interval_runtime` blobs were added.

Two subsequent red jobs were missing test fixtures only:
- PROFILE03 H03 application-host timing fixture;
- ZERO-WASTE poison-workspace fixture.

No production change was required for either.

Current focused evidence:
- FKT22 O0/O2 production runtime and physical identity: PASS;
- PPA-WU01 production application bootstrap O0/O2 and output identity: PASS;
- paired Reference runtime: PASS, mean candidate/baseline ratio `0.717335304`, mean improvement approximately 28.27%;
- paired directional runtime: PASS, mean ratio `0.746223613`, mean improvement approximately 25.38%;
- poison-workspace equivalence: PASS;
- poison free-drainage: PASS;
- poison O0/O2 identity: PASS.

The B1 production recomposition surface is 22 source files: the 20 initially identified production-behavior files plus the two proven diagnostics dependency files.

### B1 status

`B1_CORE_P0_RECOMPOSITION = QUALIFIED_ON_CURRENT_CANONICAL_BASE`

This qualifies the recomposed B1 postimage as the base for B2. It does not yet authorize direct canonical merge of PR #622; B2, PLANVALID01 and F-AHL50 remain separate bounded tranches.
