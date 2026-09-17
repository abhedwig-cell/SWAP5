# Workstream execution and recovery protocol

## Purpose

Long-running development, verification and qualification work must remain recoverable when a tool, test runner, chat session or execution environment stops unexpectedly. Git is the durable system of record. Chat reasoning, an uncommitted worktree and transient tool state are not recovery points.

The governing rule is:

```text
persist early, test second
```

This protocol applies to all SWAP5 workstreams and work units, including F-CI and F-MQ.

## Required state model

A work unit must distinguish these states explicitly:

- **implemented**: the intended change exists in a working tree or generated artifact;
- **persisted**: the recoverable postimage and its status metadata are committed to Git;
- **tested**: the declared focused checks have completed successfully against that persisted postimage;
- **qualified**: all gates required for admission of the work unit have completed successfully and their evidence is versioned;
- **blocked**: the next required action cannot currently be completed and the dependency is recorded.

These states are not interchangeable. In particular, a checkpoint commit is not evidence that a change is tested or qualified.

## Mandatory checkpoint before timeout-sensitive work

Before starting a timeout-sensitive or otherwise expensive operation, the preceding useful work must already be recoverable from Git.

Examples include:

- full or broad compilation runs;
- regression suites;
- long SWAP reference runs;
- MultiSWAP scale, concurrency or isolation tests;
- performance benchmarks;
- large repository-wide analyses or transformations;
- any operation whose interruption would otherwise require reconstructing non-trivial work.

A checkpoint must contain, directly or through versioned work-unit metadata:

```text
WORKSTREAM
WORK UNIT
BASELINE
CHECKPOINT COMMIT
FILES / ARTIFACTS PERSISTED
IMPLEMENTATION STATUS
TEST STATUS
QUALIFICATION STATUS
NEXT EXPENSIVE ACTION
RECOVERY POINT
DEPENDENCIES / BLOCKERS
```

The checkpoint commit may be temporary in the eventual history. It must nevertheless be complete enough to resume safely.

## Lightweight checks before a checkpoint

Short structural checks may run before the checkpoint when they are cheap and reduce the risk of persisting a trivially broken postimage. Examples are syntax checks, schema validation or a small focused unit test.

They do not replace the checkpoint. Long or broad gates run only after the useful postimage has been persisted.

## Checkpointing is not a stop condition

A checkpoint is a **recovery boundary**, not a default execution endpoint. Persisting a meaningful state does not require a new user instruction before work continues.

The operational rule is:

```text
persist frequently, stop rarely
```

After a checkpoint has been persisted, continue automatically with the next permitted phase while execution remains healthy and the next action is authorized and safe. A normal uninterrupted run may therefore cross several phases, for example:

```text
RECONCILE -> checkpoint -> IMPLEMENT -> checkpoint -> focused tests -> checkpoint -> QUALIFY -> CLOSE
```

Do not deliberately fragment work into one-tool-call or one-file steps merely to create more checkpoints. Reading a file, locating a symbol, running one trivial command, or completing another transient action is not by itself a useful stopping boundary.

Prefer checkpoints at **meaningful state boundaries**, such as:

- authority and relevant live state are sufficiently reconciled to resume implementation without reconstructing prior analysis;
- one atomic implementation decision has been persisted;
- a coherent focused test group has completed and its evidence is durable;
- a qualification, admission or blocking decision has been reached and recorded.

Stop after a checkpoint only when at least one of the following applies:

- a real scientific, architectural, governance or dependency blocker has been reached;
- the next action is not authorized by the current work-unit scope;
- a tool or execution environment has failed or been interrupted;
- the remaining runtime appears insufficient to start the next expensive operation safely;
- the user explicitly requested a stop or review boundary.

When runtime exhaustion appears plausible, prefer an early durable checkpoint and concrete recovery handoff over starting another long or fragile tool chain. This is a runtime-safety decision, not a reason to make the scientific work unit artificially smaller.

## Remote persistence

When work is being performed in a local or disposable environment, a local commit alone is not the strongest recovery boundary. Before a costly operation, the checkpoint should also be pushed to the workstream branch unless there is a documented reason not to do so.

For work performed directly through the GitHub repository interface, a successful repository commit already provides remote persistence.

## Work-unit status record

Material work units should maintain a versioned status record close to their other integration or qualification artifacts. Existing workstreams may keep their current naming convention, for example:

```text
integration/f-ci/F-CI07_STATUS.json
integration/f-mq/F-MQ01_STATUS.json
```

Where a workstream already has a deterministic `<WORK_UNIT>_STATUS.json` convention, keep using it. Do not create a separate repository-wide agent index merely to make discovery easier; that would become a second, easily stale source of project state.

The exact serialization may differ, but the record must make the recovery boundary unambiguous. At minimum it must state:

```text
work_unit
baseline
checkpoint_commit
implemented
persisted
tested
qualified
next_action
recovery_point
blockers
```

For new or materially updated status records, also persist bounded retrieval hints when they are known:

```text
last_reconciled_head
last_reconciled_upstream
relevant_paths
authority_paths
test_paths
evidence_paths
dependency_surface
```

These fields are navigation and recovery metadata, not replacement authority. They point to the owning source, contract, tests and evidence. The `dependency_surface` should be conservative enough to identify which later changes can invalidate reuse of prior reconciliation or evidence. If that surface is uncertain, widen the reconciliation rather than claiming unchanged dependencies.

Historical status records do not need to be retrofitted solely for this protocol. Add or improve retrieval hints when a work unit is next materially touched.

A status record must not claim `tested` or `qualified` before the corresponding gate has actually completed.

## Connector-efficient repository retrieval

Repository access through remote connectors is not equivalent to working in a persistent local clone. Repeated broad search and repository reconstruction can consume most of an execution window. Use a bounded retrieval strategy that preserves authority while minimizing unnecessary calls.

The governing retrieval rule is:

```text
status first -> exact ref -> relevant delta -> bounded files -> search only if needed
```

Apply it as follows:

1. Resolve the target branch once and pin the exact HEAD SHA for the current phase. Read material files against that exact ref rather than mixing moving branch reads.
2. If the work-unit status path is known, read it directly first. If it is not known, inspect the exact owning integration/workstream directory tree before attempting repository-wide discovery.
3. Use `relevant_paths`, `authority_paths`, `test_paths`, `evidence_paths` and `dependency_surface` from the status record when available. Fetch those paths directly at the pinned SHA.
4. On resume, compare the last persisted/reconciled commit with the current branch HEAD before reconstructing anything. If the work unit also depends on a moving canonical/upstream branch, compare the last reconciled upstream commit with its current HEAD.
5. If the resulting delta does not intersect the recorded dependency surface, preserve already-valid authority reconstruction and immutable evidence. Re-run only the incomplete action or the checks whose declared dependency surface changed.
6. If the delta intersects the dependency surface, inspect the intersecting paths and their owning contracts/tests first. Do not automatically repeat unrelated repository reconnaissance.
7. Prefer exact-ref file reads and small directory-tree traversal over a recursive full-repository tree. Escalate only when the bounded locations are genuinely insufficient.
8. Treat code-search results as **locators, not branch authority**, unless the search mechanism is explicitly scoped to the exact target ref. A path or symbol found through a default-branch index must be re-read at the pinned target SHA before it supports an implementation or qualification claim.
9. Persist newly discovered stable retrieval paths in the next meaningful work-unit status checkpoint so a later runtime does not have to rediscover them.

This strategy is an optimization of repository access, not a relaxation of scientific or architectural reconciliation. If a bounded delta cannot establish that relevant dependencies are unchanged, conservatively widen the read and reconciliation scope rather than assuming equivalence.

## Recovery after interruption

After a timeout, aborted tool call, lost runner or interrupted chat, resume from repository state rather than reconstructing from memory.

Recovery order:

1. Re-read the current workstream branch and exact HEAD commit and pin it for the recovery phase.
2. Read the latest work-unit status record and recovery point directly when its path is known; otherwise inspect the exact owning workstream directory to locate it.
3. Confirm that the referenced checkpoint postimage exists in Git.
4. Compare the checkpoint or last-reconciled commit with current HEAD, and compare the last-reconciled upstream/canonical commit when that dependency is relevant.
5. Intersect those deltas with the recorded dependency surface and retrieval paths.
6. Preserve already-persisted source, authority reconstruction and evidence when the relevant dependency surface is unchanged.
7. Re-read only changed/intersecting dependencies and re-run only the action that was incomplete or whose result was not durably recorded.
8. Do not repeat broad source reconstruction or redesign merely because the previous execution session disappeared.
9. If repository state and chat history disagree, repository state wins.

A normal recovery statement should be concrete, for example:

```text
Work unit: F-CI07
Recovery commit: <sha>
Persisted: yes
Relevant delta since checkpoint: none
Focused tests: passed
Qualification gate: incomplete
Next action: rerun qualification gate from the persisted postimage
```

## Commit discipline

Checkpoint commits should use a recognizable message, for example:

```text
checkpoint(F-CI07): persist trial capsule before regression
checkpoint(F-MQ01): persist deterministic harness before scale gate
```

Final qualification commits remain separate when useful. Checkpoint commits may later be squashed or reorganized during canonical integration, provided the qualified lineage remains reconstructible.

## Relation to architecture invariants

This is a development and qualification execution protocol. It does not change SWAP physics, numerical policy, transactional semantics, runtime semantics or the Core Architecture Invariants.

The architecture invariants define what the system must mean. This protocol defines how development work is persisted and recovered safely while reaching that system.

## Minimum rule for every new work unit

No material work unit is allowed to depend on a long-running gate while its only useful postimage exists in transient chat state or an uncommitted worktree.

Before such a gate starts, answer all three questions with a concrete repository reference:

1. What exact postimage is safe?
2. At what Git commit can work resume?
3. What is the single next incomplete action?

If those answers are not yet available, create the checkpoint first.
