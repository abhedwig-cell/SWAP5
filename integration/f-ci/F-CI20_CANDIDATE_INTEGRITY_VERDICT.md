# F-CI20 Candidate Integrity Verdict

## Decision

`QUALIFIED_ADMISSION_DAG_PERSISTED_COMPOSITION_NOT_YET_AUTHORIZED`

F-CI20 has enough source-bound evidence to classify the post-F-CI19 candidates, but not to promote or even materialize a guessed production composition.

## Admitted for later controlled composition

### F-WOF42 as primary spine

F-WOF42 is the only assessed production lane that is a direct linear descendant of the exact F-CI19 canonical base `3144c35eb8c60f822cc363dc48c21591e14b4cf4`. Its live closeout is `ed0219402072f121856d82cb6068ab74c70f34d1`.

This is an admission as the starting spine for a later candidate, not canonical admission.

### F-MR18 as transitive

F-MR18 is already in the F-WOF42 ancestry. A separate MR18 overlay would duplicate lineage and is prohibited.

### F-KT13 as source-equivalent

F-KT13 is historically divergent, but the two production kernel surfaces carrying the qualified trusted reconstruction seam are byte-identical in F-KT13 and F-WOF42:

- `src/kernel/mod_kernel_committed_persistence.f90` = `ffd886c3401fc12739a456fe60a8741c12b9848b`.
- `src/kernel/mod_kernel_transactions.f90` = `f1acff10dd99c308a00f434440d6a9ef14632f0d`.

Therefore F-KT13 needs no separate production overlay. Its qualification must still be replayed if later composition modifies the relevant transaction/persistence context.

## Replay-required and not yet materializable

### F-KT11 temporal certificate subsystem

The independently qualified remediated source is exactly `6e9a684baff6812c3e1be5286f48447a6b4bff76`, tree `d24f20559653b028d7967bf57da37da432803221`, as qualified by F-VQ34.

It is not a valid whole-branch merge candidate. It diverges from the current canonical lineage at `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`, and its temporal production surfaces differ from or are absent in F-WOF42.

The correct next action is a separate controlled materialization workunit that:

1. starts from the exact F-WOF42 postimage;
2. determines the minimal dependency-closed temporal production set from the F-KT11/F-SI25/F-KT10 lineage;
3. resolves differences intentionally rather than by branch merge;
4. persists the resulting exact source postimage before long tests;
5. replays the frozen owner and independent qualification chain on that exact postimage.

Until then F-KT11 is `REPLAY_REQUIRED`, not `ADMITTED_PRODUCTION_POSTIMAGE`.

## Qualification evidence classification

F-SI25 is owner-verified production-seam evidence, not independent qualification. F-SI26 is an owner-qualified scientific normalization candidate with no production source change. F-VQ30, F-VQ31 and F-VQ32 are positive independent evidence for their respective bounded indicator, transaction-history and normalization scopes, but each is bound to an older source tree and therefore requires replay on a new composition.

F-VQ33 is permanently retained as a failed qualification node for candidate source `931809dbff3b6fed5ae4ef62ff22e127b4bb1da2`. Its failure identified loss of the native invalid-budget diagnostic and must not be counted as positive evidence.

F-VQ34 is the positive independent successor. It qualifies exact remediated candidate source `6e9a684baff6812c3e1be5286f48447a6b4bff76`. That PASS does not transfer automatically to a future composition tree.

## Architecture verdict

The admission plan is compatible with the SWAP architecture invariants because it does not add a second kernel, move I/O into the kernel, persist scratch, weaken transaction boundaries, change physics through solver policy, relax hard mass conservation, or introduce calendar assumptions. It also avoids duplicating already-equivalent KT13 production code and avoids wholesale ingestion of a stale divergent temporal branch.

The main remaining risk is source composition, not scientific semantics: the KT11 temporal chain depends on production interfaces that have moved independently in the WOF42 spine. Treating a green historical branch as directly mergeable would erase that distinction and would make prior qualification claims non-auditable.

## State

- admission manifest: persisted;
- replay matrix: persisted;
- candidate classification: persisted;
- production composition: not performed;
- production `src/` changes by F-CI20: none;
- canonical branch update: not performed;
- canonical promotion: not authorized;
- next work: controlled dependency-closed temporal materialization plus replay qualification on an exact WOF42-derived postimage.
